import 'dart:async';

import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/threshold_engine.dart';
import 'package:temp_monitor/infrastructure/ble_scanner.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/mock_sensor.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

/// Runs the scan loop (real BLE or mock) inside the **main isolate**.
///
/// Readings are persisted to [repository] and forwarded to [readingStream]
/// for any consumer (e.g. DashboardCubit) to subscribe to.
///
/// This avoids the crash-prone multi-isolate architecture of
/// flutter_background_service while keeping the same data flow.
class ScanService {
  final SensorRepository _repository;
  final SettingsService _settings;
  final BleScanner _scanner;
  final MockSensor _mockSensor;
  final NotificationService _notifications;
  final StreamController<Reading> _controller =
      StreamController<Reading>.broadcast();

  Timer? _scanTimer;
  StreamSubscription<Reading>? _mockSubscription;
  ThresholdEngine _thresholdEngine;
  bool _started = false;

  /// Broadcast stream that any consumer (DashboardCubit, etc.) can listen to.
  Stream<Reading> get readingStream => _controller.stream;

  ScanService({
    required SensorRepository repository,
    required SettingsService settings,
    required NotificationService notifications,
  })  : _repository = repository,
        _settings = settings,
        _scanner = BleScanner(),
        _mockSensor = MockSensor(),
        _notifications = notifications,
        _thresholdEngine = _createEngine(settings);

  static ThresholdEngine _createEngine(SettingsService settings) =>
      ThresholdEngine(
        tempMin: settings.getTempMin(),
        tempMax: settings.getTempMax(),
        humidityMin: settings.getHumidityMin(),
        humidityMax: settings.getHumidityMax(),
      );

  /// Start scanning. Safe to call multiple times — will cancel any
  /// existing scan and restart with current settings.
  void start() {
    _started = true;
    _thresholdEngine = _createEngine(_settings);
    _cancelAll();

    final interval = Duration(seconds: _settings.getScanIntervalSeconds());

    if (_settings.getMockDeviceEnabled()) {
      DebugLogger().i('Starting mock sensor stream', tag: 'ScanService');
      _mockSubscription = _mockSensor
          .readings(deviceId: 'mock-device', interval: interval)
          .listen(_handleReading);
      return;
    }

    DebugLogger().i('Starting BLE scanner', tag: 'ScanService');
    _scanTimer = Timer.periodic(interval, (_) async {
      try {
        await for (final reading
            in _scanner.scan(timeout: const Duration(seconds: 2))) {
          _handleReading(reading);
        }
      } catch (e) {
        DebugLogger().e('Scan error: $e', tag: 'ScanService');
      }
    });
  }

  /// Restart scanning with latest settings.
  void restart() => start();

  /// Stop all scanning and clean up.
  void stop() {
    _started = false;
    _cancelAll();
  }

  bool get isRunning => _started;

  void _handleReading(Reading reading) {
    // Persist to database so watchAllDevices() fires.
    _repository.saveReading(reading).catchError((e) {
      DebugLogger().e('Failed to persist reading: $e', tag: 'ScanService');
    });

    // Forward to any consumer (DashboardCubit, etc.).
    _controller.add(reading);

    // Evaluate thresholds and fire notification if breached.
    final state = _thresholdEngine.evaluate(
      temperature: reading.temperature,
      humidity: reading.humidity,
    );

    if (state.justBecameBreached) {
      _notifications.showAlert(
        title: '温湿度告警',
        body:
            '温度 ${reading.temperature}°C / 湿度 ${reading.humidity}% 超出设定范围',
      );
    }
  }

  void _cancelAll() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _mockSubscription?.cancel();
    _mockSubscription = null;
  }

  /// Dispose the service. No further readings will be processed.
  void dispose() {
    stop();
    _controller.close();
  }
}
