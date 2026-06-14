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
/// The background service ([BackgroundService]) handles all periodic BLE
/// scanning in its own isolate, surviving app suspension. The main isolate
/// only receives readings via [IsolateNameServer] and processes them
/// (dedup, persist, notify, forward to UI).
///
/// If the background service is unavailable, the main isolate falls back
/// to a [Timer.periodic] — scanning pauses when the app is backgrounded
/// but data collection continues while the app is in the foreground.
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

  /// When true, the background service handles BLE scanning and DB persistence.
  /// The main isolate only forwards readings to UI and evaluates thresholds.
  /// When false, the main isolate does everything (fallback mode).
  bool _backgroundMode = false;

  /// Tracks the last saved reading per device to avoid writing duplicates.
  /// Keyed by deviceId; only updated when a new value is actually persisted.
  final _lastSaved = <String, Reading>{};

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
  /// Sets up the ReceivePort for readings from the background isolate, then
  /// starts the background service for periodic BLE scanning. In mock mode,
  /// the mock sensor stream runs in the main isolate instead.
  ///
  /// If the background service is unavailable (e.g. not configured), falls
  /// back to a main-isolate [Timer.periodic] — scanning pauses when the
  /// app is backgrounded but works while foregrounded.
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

    if (_currentMockMode) {
      // Mock mode runs in the main isolate — no BLE scanning needed.
      _backgroundMode = false;
      final interval = Duration(seconds: _currentIntervalSec);
      DebugLogger().i('Starting mock sensor stream', tag: 'ScanService');
      _mockSubscription = _mockSensor
          .readings(deviceId: 'mock-device', interval: interval)
          .listen(_handleReading);
      return;
    }

    // Set up the ReceivePort so the background isolate can send us readings.
    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, AppConstants.uiIsolatePortName);
    _receivePort!.listen((message) {
      if (message is Reading) {
        _handleReading(message);
      } else if (message == null) {
        // Heartbeat from background service — confirm it's alive.
        DebugLogger().v('Background service heartbeat', tag: 'ScanService');
      }
    });

    // If the background service is available, it handles all BLE scanning
    // AND DB persistence. The main isolate only forwards readings to UI
    // and evaluates thresholds for notifications.
    if (BackgroundService.isAvailable) {
      _backgroundMode = true;
      DebugLogger().i('Using background service for BLE scanning',
          tag: 'ScanService');
      BackgroundService.start();
      return;
    }

    // Fallback: background service not available — scan from main isolate.
    _backgroundMode = false;
    DebugLogger().i('Background service unavailable, using main-isolate BLE scanner',
        tag: 'ScanService');
    _startMainIsolateTimer();
  }

  void _startMainIsolateTimer() {
    final interval = Duration(seconds: _currentIntervalSec);

    DebugLogger().i('Starting BLE scanner (main isolate)', tag: 'ScanService');
    _scanTimer = Timer.periodic(interval, (_) async {
      try {
        await _scanner.scan(timeout: const Duration(seconds: 4));
      } catch (e) {
        DebugLogger().e('Scan error: $e', tag: 'ScanService');
      }
    });
  }

  void restart() {
    // Re-read settings and push them to the background service if running.
    _thresholdEngine = _createEngine(_settings);
    if (BackgroundService.isAvailable) {
      BackgroundService.updateSettings();
    } else {
      start();
    }
  }

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

  void _handleReading(Reading reading) {
    // Skip readings that carry no temperature or humidity data (e.g.
    // battery-only lifecycle packets from ATC sensors). Don't update
    // _lastSaved either, so a subsequent real reading won't be seen as
    // "unchanged" against a null-metric reading.
    if (reading.temperature == null && reading.humidity == null) {
      DebugLogger().v(
          'Skip save (no temp/humidity) ${reading.deviceId}',
          tag: 'ScanService');
      return;
    }

    // Skip persisting when the value is identical to the last saved one.
    // BLE sensors broadcast every ~200ms during a scan window — without
    // dedup a single 10s window writes dozens of identical rows to the DB.
    //
    // In background mode, the background isolate already persists readings
    // to DB — the main isolate only saves when running its own fallback
    // scanner.
    final prev = _lastSaved[reading.deviceId];
    if (!_backgroundMode) {
      if (prev == null ||
          prev.temperature != reading.temperature ||
          prev.humidity != reading.humidity ||
          prev.battery != reading.battery) {
        _lastSaved[reading.deviceId] = reading;
        _repository.saveReading(reading).catchError((e) {
          DebugLogger().e('Failed to persist reading: $e', tag: 'ScanService');
        });
      } else {
        DebugLogger().v(
            'Skip save (unchanged) ${reading.deviceId}: '
            '${reading.temperature?.toStringAsFixed(1) ?? "?"}°C '
            '${reading.humidity?.toStringAsFixed(1) ?? "?"}%',
            tag: 'ScanService');
      }
    }

    _controller.add(reading);

    final state = _thresholdEngine.evaluate(
      temperature: reading.temperature,
      humidity: reading.humidity,
    );

    if (state.justBecameBreached) {
      _notifications.showAlert(
        title: '温湿度告警',
        body:
            '温度 ${reading.temperature?.toStringAsFixed(1) ?? "?"}°C / '
            '湿度 ${reading.humidity?.toStringAsFixed(1) ?? "?"}% 超出设定范围',
      );
    } else if (state.justRecovered) {
      _notifications.showAlert(
        title: '温湿度已恢复',
        body:
            '温度 ${reading.temperature?.toStringAsFixed(1) ?? "?"}°C / '
            '湿度 ${reading.humidity?.toStringAsFixed(1) ?? "?"}% 已回到正常范围',
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
