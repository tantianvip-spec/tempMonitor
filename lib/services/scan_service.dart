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
/// Tracks the current mode so redundant [restart] calls are no-ops.
/// BLE scanning only runs when explicitly started; the mock sensor
/// stream replaces it when mock mode is enabled.
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
  bool _currentMockMode = false;
  int _currentIntervalSec = 0;

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

  /// Start scanning. Idempotent — safe to call many times.
  void start() {
    _thresholdEngine = _createEngine(_settings);
    final mockMode = _settings.getMockDeviceEnabled();
    final intervalSec = _settings.getScanIntervalSeconds();

    DebugLogger().d(
      'ScanService.start() called — mock=$mockMode interval=${intervalSec}s '
      'started=$_started prevMock=$_currentMockMode prevInterval=$_currentIntervalSec\n'
      'Stack: ${StackTrace.current}',
      tag: 'ScanService',
    );

    // Skip if already running with same mode and interval.
    if (_started &&
        mockMode == _currentMockMode &&
        intervalSec == _currentIntervalSec) {
      DebugLogger().d('ScanService.start() — skip, no change', tag: 'ScanService');
      return;
    }

    _currentMockMode = mockMode;
    _currentIntervalSec = intervalSec;
    _cancelAll();
    _started = true;

    final interval = Duration(seconds: intervalSec);

    if (mockMode) {
      DebugLogger().i('Starting mock sensor stream', tag: 'ScanService');
      _mockSubscription = _mockSensor
          .readings(deviceId: 'mock-device', interval: interval)
          .listen(_handleReading);
      return;
    }

    DebugLogger().i('Starting BLE scanner', tag: 'ScanService');
    _scanTimer = Timer.periodic(interval, (_) async {
      // Re-check mock mode on each tick in case it was toggled
      // between BLE scan cycles.
      if (_settings.getMockDeviceEnabled()) {
        _currentMockMode = true;
        _scanTimer?.cancel();
        _scanTimer = null;
        DebugLogger().i(
            'Switching from BLE to mock mid-tick', tag: 'ScanService');
        _mockSubscription = _mockSensor
            .readings(deviceId: 'mock-device', interval: interval)
            .listen(_handleReading);
        return;
      }

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

  /// Restart scanning with latest settings. Idempotent.
  void restart() => start();

  /// Stop all scanning and clean up.
  void stop() {
    _started = false;
    _cancelAll();
  }

  bool get isRunning => _started;

  void _handleReading(Reading reading) {
    _repository.saveReading(reading).catchError((e) {
      DebugLogger().e('Failed to persist reading: $e', tag: 'ScanService');
    });

    _controller.add(reading);

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
