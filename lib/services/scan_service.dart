import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/threshold_engine.dart';
import 'package:temp_monitor/infrastructure/background_service.dart';
import 'package:temp_monitor/infrastructure/ble_scanner.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/mock_sensor.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

/// Coordinates scanning between the background service and main isolate.
///
/// Attempts to use [BackgroundService] for periodic scanning that survives
/// app suspension. If the background service fails to start, falls back
/// to a main-isolate [Timer.periodic] — scanning pauses when the app is
/// backgrounded but the app never crashes.
///
/// On-demand scanning (devices page) always runs in the main isolate.
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
  ReceivePort? _receivePort;

  /// Broadcast stream that any consumer (DashboardCubit, etc.) can listen to.
  Stream<Reading> get readingStream => _controller.stream;

  /// Real-time stream of BLE scan results (nearby devices + BThome readings).
  Stream<ScanResultBundle> get nearbyDevices => _scanner.scanResults;

  ScanService({
    required SensorRepository repository,
    required SettingsService settings,
    required NotificationService notifications,
  })  : _repository = repository,
        _settings = settings,
        _scanner = BleScanner(),
        _mockSensor = MockSensor(),
        _notifications = notifications,
        _thresholdEngine = _createEngine(settings) {
    _scanner.onReading = _handleReading;
  }

  static ThresholdEngine _createEngine(SettingsService settings) =>
      ThresholdEngine(
        tempMin: settings.getTempMin(),
        tempMax: settings.getTempMax(),
        humidityMin: settings.getHumidityMin(),
        humidityMax: settings.getHumidityMax(),
      );

  /// Start scanning. Idempotent.
  ///
  /// Always starts the main-isolate [Timer.periodic] for guaranteed data
  /// collection. Also attempts to start the [BackgroundService] for data
  /// collection when the app is suspended — if it fails, the main-isolate
  /// timer continues uninterrupted.
  void start() {
    _thresholdEngine = _createEngine(_settings);
    final mockMode = _settings.getMockDeviceEnabled();
    final intervalSec = _settings.getScanIntervalSeconds();

    if (_started &&
        mockMode == _currentMockMode &&
        intervalSec == _currentIntervalSec) {
      return;
    }

    _currentMockMode = mockMode;
    _currentIntervalSec = intervalSec;
    _cancelAll();
    _started = true;

    // Set up the ReceivePort so the background isolate can send us readings.
    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, AppConstants.uiIsolatePortName);
    _receivePort!.listen((message) {
      if (message is Reading) {
        _controller.add(message);
      }
    });

    // Try to start the background service (best-effort). It handles its
    // own errors internally so this never throws. If it succeeds, readings
    // will also arrive via the ReceivePort above.
    BackgroundService.start();

    // Always start the main-isolate timer. If the background service is
    // also running, duplicate readings are harmless (BleScanner debounces
    // them per instance, and each instance writes to the DB independently).
    _startMainIsolateTimer();
  }

  void _startMainIsolateTimer() {
    final interval = Duration(seconds: _currentIntervalSec);

    if (_currentMockMode) {
      DebugLogger().i('Starting mock sensor stream', tag: 'ScanService');
      _mockSubscription = _mockSensor
          .readings(deviceId: 'mock-device', interval: interval)
          .listen(_handleReading);
      return;
    }

    DebugLogger().i('Starting BLE scanner (main isolate)', tag: 'ScanService');
    _scanTimer = Timer.periodic(interval, (_) async {
      if (_settings.getMockDeviceEnabled()) {
        _currentMockMode = true;
        _scanTimer?.cancel();
        _scanTimer = null;
        _mockSubscription = _mockSensor
            .readings(deviceId: 'mock-device', interval: interval)
            .listen(_handleReading);
        return;
      }

      try {
        await _scanner.scan(timeout: _scanWindowFor(_currentIntervalSec));
      } catch (e) {
        DebugLogger().e('Scan error: $e', tag: 'ScanService');
      }
    });
  }

  void restart() => start();

  void forceRestart() {
    _currentMockMode = !_settings.getMockDeviceEnabled();
    _currentIntervalSec = -1;
    start();
  }

  Future<void> scanNow() async {
    if (_settings.getMockDeviceEnabled()) return;
    DebugLogger().i('ScanService.scanNow() — immediate BLE scan',
        tag: 'ScanService');
    try {
      await _scanner.scan(timeout: const Duration(seconds: 4));
    } catch (e) {
      DebugLogger().e('scanNow error: $e', tag: 'ScanService');
    }
  }

  void stop() {
    _started = false;
    _cancelAll();
    _receivePort?.close();
    _receivePort = null;
    IsolateNameServer.removePortNameMapping(AppConstants.uiIsolatePortName);
  }

  bool get isRunning => _started;

  /// Compute a sensible scan window for a given interval.
  ///
  /// The window should be long enough to collect a complete BThome reading
  /// from sensors that split temp/humidity across separate advertisements
  /// (~3s is enough), but never exceed the interval so the timer doesn't
  /// overlap itself. Capped at 10 seconds to avoid excessive battery drain
  /// on very long intervals.
  static Duration _scanWindowFor(int intervalSec) {
    final window = (intervalSec * 1000 ~/ 2).clamp(3000, 10000);
    return Duration(milliseconds: window);
  }

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

  void dispose() {
    stop();
    _controller.close();
  }
}
