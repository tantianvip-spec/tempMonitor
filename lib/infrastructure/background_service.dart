import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/data/app_database.dart' hide Reading;
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/threshold_engine.dart';
import 'package:temp_monitor/infrastructure/ble_scanner.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/mock_sensor.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

/// Manages a persistent foreground service that keeps BLE scanning alive
/// even when the app is backgrounded.
///
/// The service runs in its own Dart isolate. Readings are sent to the UI
/// isolate via [IsolateNameServer] under [AppConstants.uiIsolatePortName].
class BackgroundService {
  static const int _notificationId = 888;
  static bool _configured = false;

  /// Whether the background service was successfully configured and is
  /// available for use. Check before calling [start] if you need a
  /// fallback path.
  static bool get isAvailable => _configured;

  /// Initialize the background service configuration.
  /// This must be called once during app startup (before [start]).
  static Future<void> initialize() async {
    if (_configured) return;
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'temp_monitor_service',
        initialNotificationTitle: '温湿度监控',
        initialNotificationContent: '正在后台监听设备...',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    _configured = true;
  }

  /// Start the foreground service.
  static Future<void> start() async {
    if (!_configured) return;
    final service = FlutterBackgroundService();
    await service.startService();
  }

  /// Stop the foreground service.
  static void stop() {
    if (!_configured) return;
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    } catch (_) {}
  }

  /// Send updated settings to the running background service.
  static void updateSettings() {
    if (!_configured) return;
    try {
      final service = FlutterBackgroundService();
      service.invoke('updateSettings');
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    try {
      DartPluginRegistrant.ensureInitialized();

      // Ensure Android foreground service notification is shown.
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '温湿度监控',
          content: '正在后台监听设备...',
        );
        await service.setAsForegroundService();
      }

      final settings = SettingsService();
      await settings.initialize();

      final db = AppDatabase();
      final repository = SensorRepository(db);
      final scanner = BleScanner();
      final mockSensor = MockSensor();

      // Note: NotificationService uses flutter_local_notifications which
      // requires the main isolate's platform channels. In the background
      // isolate it may not work on all devices, so wrap in try-catch.
      NotificationService? notifications;
      try {
        notifications = NotificationService();
        await notifications.initialize();
      } catch (e) {
        DebugLogger().w('Background notifications unavailable: $e',
            tag: 'BackgroundService');
      }

      ThresholdEngine createEngine() => ThresholdEngine(
            tempMin: settings.getTempMin(),
            tempMax: settings.getTempMax(),
            humidityMin: settings.getHumidityMin(),
            humidityMax: settings.getHumidityMax(),
          );

      var thresholdEngine = createEngine();

      // The UI isolate registers a ReceivePort under this name when it starts.
      // Look it up each tick so a UI hot-restart (which re-registers) is picked up.
      SendPort? uiPort;

      /// Process a single Reading: persist, push to UI, fire alert if breached.
      Future<void> handleReading(Reading reading) async {
        try {
          await repository.saveReading(reading);
        } catch (e) {
          DebugLogger().e('Background save error: $e', tag: 'BackgroundService');
        }

        uiPort ??=
            IsolateNameServer.lookupPortByName(AppConstants.uiIsolatePortName);
        uiPort?.send(reading);

        final state = thresholdEngine.evaluate(
          temperature: reading.temperature,
          humidity: reading.humidity,
        );

        if (state.justBecameBreached && notifications != null) {
          try {
            await notifications.showAlert(
              title: '温湿度告警',
              body:
                  '温度 ${reading.temperature}°C / 湿度 ${reading.humidity}% 超出设定范围',
            );
          } catch (e) {
            DebugLogger().e('Background notify error: $e',
                tag: 'BackgroundService');
          }
        }
      }

      Timer? scanTimer;
      StreamSubscription<Reading>? mockSubscription;

      void cancelAll() {
        scanTimer?.cancel();
        scanTimer = null;
        mockSubscription?.cancel();
        mockSubscription = null;
      }

      void startScanning() {
        cancelAll();
        final interval = Duration(seconds: settings.getScanIntervalSeconds());

        if (settings.getMockDeviceEnabled()) {
          DebugLogger().i('Background mock sensor started',
              tag: 'BackgroundService');
          mockSubscription = mockSensor
              .readings(deviceId: 'mock-device', interval: interval)
              .listen((reading) async {
            try {
              await handleReading(reading);
            } catch (e) {
              DebugLogger()
                  .e('Mock handler error: $e', tag: 'BackgroundService');
            }
          });
          return;
        }

        DebugLogger().i('Background BLE scanning started',
            tag: 'BackgroundService');
        scanTimer = Timer.periodic(interval, (_) async {
          try {
            await scanner.scan(timeout: const Duration(seconds: 15));
          } catch (e) {
            DebugLogger()
                .e('Background scan error: $e', tag: 'BackgroundService');
          }
        });
      }

      // Wire the scanner's reading callback.
      scanner.onReading = (Reading reading) {
        handleReading(reading).catchError((e) {
          DebugLogger().e('Background handleReading error: $e',
              tag: 'BackgroundService');
        });
      };

      service.on('stopService').listen((event) {
        cancelAll();
        service.stopSelf();
      });

      service.on('updateSettings').listen((event) {
        thresholdEngine = createEngine();
        startScanning();
      });

      startScanning();
    } catch (e, s) {
      DebugLogger().e(
        'BackgroundService onStart error: $e\n$s',
        tag: 'BackgroundService',
      );
    }
  }
}
