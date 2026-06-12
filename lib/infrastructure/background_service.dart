import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:temp_monitor/core/constants.dart';
// drift generates a `Reading` row class that collides with our domain model.
import 'package:temp_monitor/data/app_database.dart' hide Reading;
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/threshold_engine.dart';
import 'package:temp_monitor/infrastructure/ble_scanner.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/mock_sensor.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'temp_monitor_service',
        initialNotificationTitle: '温湿度监控',
        initialNotificationContent: '正在后台监听设备...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  static void onStart(ServiceInstance service) async {
    try {
      DartPluginRegistrant.ensureInitialized();

      final settings = SettingsService();
      await settings.initialize();

      final db = AppDatabase();
      final repository = SensorRepository(db);
      final scanner = BleScanner();
      final mockSensor = MockSensor();
      final notifications = NotificationService();
      await notifications.initialize();

      ThresholdEngine createEngine() => ThresholdEngine(
            tempMin: settings.getTempMin(),
            tempMax: settings.getTempMax(),
            humidityMin: settings.getHumidityMin(),
            humidityMax: settings.getHumidityMax(),
          );

      var thresholdEngine = createEngine();

      SendPort? uiPort =
          IsolateNameServer.lookupPortByName(AppConstants.uiIsolatePortName);

      Future<void> handleReading(Reading reading) async {
        try {
          await repository.saveReading(reading);
          uiPort ??=
              IsolateNameServer.lookupPortByName(AppConstants.uiIsolatePortName);
          uiPort?.send(reading);

          final state = thresholdEngine.evaluate(
            temperature: reading.temperature,
            humidity: reading.humidity,
          );

          if (state.justBecameBreached) {
            await notifications.showAlert(
              title: '温湿度告警',
              body:
                  '温度 ${reading.temperature}°C / 湿度 ${reading.humidity}% 超出设定范围',
            );
          }
        } catch (e) {
          DebugLogger()
              .e('handleReading error: $e', tag: 'BackgroundService');
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
          DebugLogger()
              .i('Starting mock sensor stream', tag: 'BackgroundService');
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

        scanTimer = Timer.periodic(interval, (_) async {
          try {
            await for (final reading
                in scanner.scan(timeout: const Duration(seconds: 2))) {
              await handleReading(reading);
            }
          } catch (e) {
            DebugLogger()
                .e('Background scan error: $e', tag: 'BackgroundService');
          }
        });
      }

      service.on('stopService').listen((event) {
        cancelAll();
        service.stopSelf();
      });

      service.on('updateSettings').listen((event) {
        thresholdEngine = createEngine();
        startScanning();
      });

      startScanning();
    } catch (e) {
      DebugLogger().e('BackgroundService onStart error: $e', tag: 'BackgroundService');
    }
  }
}