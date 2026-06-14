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
/// BLE scanning always runs in the main isolate via a [Timer.periodic],
/// because [FlutterBluePlus]'s native Android channels don't work reliably
/// in background isolates.
///
/// The background service ([BackgroundService]) is started for process
/// keepalive only — it sends periodic heartbeats to confirm the process
/// is alive, so the main-isolate Timer continues to fire when the app is
/// backgrounded or the screen is locked.
///
/// If the background service is unavailable, scanning pauses when the app
/// is backgrounded but works while foregrounded.
///
/// On-demand scanning (devices page) also runs in the main isolate via
/// [scanNow].
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

  /// Tracks which devices have been persisted in the current scan tick,
  /// so duplicate BLE callbacks within the same window don't cause
  /// redundant DB writes. Cleared at the end of each scan tick.
  final Set<String> _tickSaved = {};

  /// True while a continuous discovery scan loop is running.
  bool _discoveryScanning = false;


  /// Cached set of known device IDs, refreshed each scan tick so newly
  /// added devices are picked up without a restart.
  Set<String> _knownDeviceIds = {};

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
  /// Sets up the ReceivePort for heartbeats from the background isolate,
  /// starts the background service for process keepalive, and runs the
  /// actual BLE scanning Timer in the main isolate.
  ///
  /// All BLE scanning happens in the main isolate because
  /// [FlutterBluePlus]'s native Android channels don't work reliably in
  /// background isolates. The background service is used only to keep the
  /// process alive so the main-isolate Timer continues to fire when the
  /// app is backgrounded.
  ///
  /// In mock mode, the mock sensor stream runs in the main isolate instead.
  void start() {
    _thresholdEngine = _createEngine(_settings);
    final mockMode = _settings.getMockDeviceEnabled();
    final intervalSec = _settings.getScanIntervalSeconds();

    if (_started &&
        mockMode == _currentMockMode &&
        intervalSec == _currentIntervalSec) {
      return;
    }

    DebugLogger().i(
        'ScanService.start() mock=$mockMode interval=${intervalSec}s',
        tag: 'ScanService');

    _currentMockMode = mockMode;
    _currentIntervalSec = intervalSec;
    _cancelAll();
    _started = true;

    if (_currentMockMode) {
      final interval = Duration(seconds: _currentIntervalSec);
      DebugLogger().i('Starting mock sensor stream (interval: ${interval.inSeconds}s)',
          tag: 'ScanService');
      _mockSubscription = _mockSensor
          .readings(deviceId: 'mock-device', interval: interval)
          .listen(_handleReading);
      return;
    }

    // Set up the ReceivePort so the background isolate can send us
    // heartbeats. We do NOT receive BLE readings from the background
    // isolate anymore — all scanning is in the main isolate.
    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, AppConstants.uiIsolatePortName);
    _receivePort!.listen((message) {
      if (message == null) {
        // Heartbeat from background service — confirm process is alive.
        DebugLogger().v('Background service heartbeat', tag: 'ScanService');
      }
    });

    // Start the background service for process keepalive. This keeps the
    // Android process alive when the app is backgrounded, so our
    // main-isolate Timer continues to fire.
    if (BackgroundService.isAvailable) {
      DebugLogger().i(
          'Starting background service for keepalive + '
          'main-isolate BLE scanner (interval: ${intervalSec}s)',
          tag: 'ScanService');
      BackgroundService.start();
    } else {
      DebugLogger().w(
          'Background service unavailable — scanning stops when app is backgrounded',
          tag: 'ScanService');
    }

    // Always start the BLE scanner in the main isolate.
    _startMainIsolateTimer();
  }

  void _startMainIsolateTimer() {
    final interval = Duration(seconds: _currentIntervalSec);

    DebugLogger().i(
        'Main-isolate BLE scanner started (interval: ${interval.inSeconds}s)',
        tag: 'ScanService');
    _scanTimer = Timer.periodic(interval, (_) async {
      DebugLogger().d('Scan tick starting', tag: 'ScanService');
      // Clear per-tick dedup set before the scan window starts.
      // This ensures each device is persisted at most once per tick,
      // even if BLE delivers duplicate broadcasts of the same packet.
      _tickSaved.clear();
      try {
        // Refresh known device IDs each tick so newly added devices are
        // picked up immediately without a service restart.
        final devices = await _repository.getAllDevices();
        _knownDeviceIds = devices.map((d) => d.id).toSet();
        DebugLogger().v(
            'Known devices: ${_knownDeviceIds.length}',
            tag: 'ScanService');

        // Scan window (15s) must exceed the sensor's advertising interval
        // (ATC_PVVX: ~5-10s) so we reliably catch at least one broadcast
        // even if the first one is missed by a few ms.
        await _scanner.scan(
          timeout: const Duration(seconds: 15),
          knownDeviceIds: _knownDeviceIds.isEmpty ? null : _knownDeviceIds,
        );
      } catch (e) {
        DebugLogger().e('Scan error: $e', tag: 'ScanService');
      }
    });
  }

  void restart() {
    // Re-read settings. Since the scan interval may have changed, always
    // restart from scratch.
    DebugLogger().i(
        'restart() — interval=${_settings.getScanIntervalSeconds()}s '
        'mock=${_settings.getMockDeviceEnabled()}',
        tag: 'ScanService');
    _started = false;
    start();
  }

  void forceRestart() {
    _currentMockMode = !_settings.getMockDeviceEnabled();
    _currentIntervalSec = -1;
    start();
  }

  /// Trigger an immediate monitoring scan for known devices.
  /// Used by the manual refresh button / pull-to-refresh on the device list.
  Future<void> refreshNow() async {
    if (_settings.getMockDeviceEnabled()) return;
    DebugLogger().i(
        'refreshNow() — immediate monitoring scan',
        tag: 'ScanService');
    _tickSaved.clear();
    try {
      final devices = await _repository.getAllDevices();
      _knownDeviceIds = devices.map((d) => d.id).toSet();
      await _scanner.scan(
        timeout: const Duration(seconds: 15),
        knownDeviceIds: _knownDeviceIds.isEmpty ? null : _knownDeviceIds,
      );
    } catch (e) {
      DebugLogger().e('refreshNow error: $e', tag: 'ScanService');
    }
  }

  Future<void> scanNow() async {
    if (_settings.getMockDeviceEnabled()) return;
    DebugLogger().i(
        'scanNow() — immediate on-demand BLE scan (discovery mode)',
        tag: 'ScanService');
    try {
      // On-demand scans for device discovery: show ALL BLE devices,
      // not just already-known ones. Keep this short — user is waiting.
      await _scanner.scanForDiscovery(timeout: const Duration(seconds: 4));
    } catch (e) {
      DebugLogger().e('scanNow error: $e', tag: 'ScanService');
    }
  }

  /// Start a continuous BLE discovery scan that runs until [stopDiscoveryScan]
  /// is called. Used by the devices page drawer — keeps scanning so new
  /// sensors appear in real time until the user taps "停止扫描".
  Future<void> startDiscoveryScan() async {
    if (_settings.getMockDeviceEnabled()) return;
    if (_discoveryScanning) return;
    _discoveryScanning = true;
    DebugLogger().i(
        'startDiscoveryScan() — continuous scan for device discovery',
        tag: 'ScanService');
    // Runs 3s scan windows in a loop. Between windows the BLE stack gets a
    // brief rest, and the loop checks _discoveryScanning before the next
    // window. When the user stops, the current window finishes and the loop
    // exits naturally.
    while (_discoveryScanning) {
      await _scanner.scanForDiscovery(timeout: const Duration(seconds: 3));
    }
  }

  /// Stop the continuous discovery scan.
  void stopDiscoveryScan() {
    _discoveryScanning = false;
    _scanner.stopScan();
    DebugLogger().i(
        'stopDiscoveryScan() — continuous scan stopped',
        tag: 'ScanService');
  }

  void stop() {
    _started = false;
    _discoveryScanning = false;
    _cancelAll();
    _receivePort?.close();
    _receivePort = null;
    IsolateNameServer.removePortNameMapping(AppConstants.uiIsolatePortName);
  }

  bool get isRunning => _started;

  void _handleReading(Reading reading) {
    // Skip readings that carry no temperature or humidity data (e.g.
    // battery-only lifecycle packets from ATC sensors). Don't update
    // _tickSaved either, so a subsequent real reading won't be blocked.
    if (reading.temperature == null && reading.humidity == null) {
      DebugLogger().v(
          'Skip save (no temp/humidity) ${reading.deviceId}',
          tag: 'ScanService');
      return;
    }

    // Per-tick dedup: within one scan window, BLE may deliver the same
    // broadcast packet multiple times. Only persist the first occurrence
    // per device per tick. Cross-tick, every device is written once even
    // if the value hasn't changed, so the history chart is continuous.
    if (!_tickSaved.add(reading.deviceId)) {
      DebugLogger().v(
          'Skip duplicate save (already saved this tick) ${reading.deviceId}',
          tag: 'ScanService');
      return;
    }

    // Always persist every reading to DB so the history chart shows
    // continuous data even when the sensor value hasn't changed.
    DebugLogger().i(
        'Persist ${reading.deviceId}: '
        '${reading.temperature?.toStringAsFixed(1) ?? "?"}°C '
        '${reading.humidity?.toStringAsFixed(1) ?? "?"}% '
        'batt=${reading.battery ?? "?"}',
        tag: 'ScanService');
    _repository.saveReading(reading).catchError((e) {
      DebugLogger().e('Failed to persist reading: $e', tag: 'ScanService');
    });

    _controller.add(reading);

    final state = _thresholdEngine.evaluate(
      temperature: reading.temperature,
      humidity: reading.humidity,
    );

    if (state.justBecameBreached) {
      DebugLogger().w(
          'Threshold breached! ${reading.deviceId}: '
          '${reading.temperature?.toStringAsFixed(1) ?? "?"}°C / '
          '${reading.humidity?.toStringAsFixed(1) ?? "?"}%',
          tag: 'ScanService');
      _notifications.showAlert(
        title: '温湿度告警',
        body:
            '温度 ${reading.temperature?.toStringAsFixed(1) ?? "?"}°C / '
            '湿度 ${reading.humidity?.toStringAsFixed(1) ?? "?"}% 超出设定范围',
      );
    } else if (state.justRecovered) {
      DebugLogger().i(
          'Threshold recovered! ${reading.deviceId}: '
          '${reading.temperature?.toStringAsFixed(1) ?? "?"}°C / '
          '${reading.humidity?.toStringAsFixed(1) ?? "?"}%',
          tag: 'ScanService');
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
