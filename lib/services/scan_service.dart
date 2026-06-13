import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/infrastructure/background_service.dart';
import 'package:temp_monitor/infrastructure/ble_scanner.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

/// Coordinates scanning between the UI isolate and the background service.
///
/// **Periodic BLE scanning** (for data collection) runs in the background
/// service isolate via [BackgroundService], so it survives app suspension.
///
/// **On-demand scanning** (for the devices page — nearby device list) runs
/// here in the main isolate via [BleScanner.scan].
///
/// Readings from the background isolate arrive via [IsolateNameServer] and
/// are forwarded to [readingStream] for the DashboardCubit to consume.
class ScanService {
  final SensorRepository _repository;
  final SettingsService _settings;
  final BleScanner _scanner;
  final StreamController<Reading> _controller =
      StreamController<Reading>.broadcast();

  ReceivePort? _receivePort;

  /// Broadcast stream that any consumer (DashboardCubit, etc.) can listen to.
  Stream<Reading> get readingStream => _controller.stream;

  /// Real-time stream of BLE scan results (nearby devices + BThome readings).
  /// Emitted after each on-demand scan window.
  Stream<ScanResultBundle> get nearbyDevices => _scanner.scanResults;

  ScanService({
    required SensorRepository repository,
    required SettingsService settings,
  })  : _repository = repository,
        _settings = settings,
        _scanner = BleScanner() {
    // Wire the BLE scanner callback for on-demand scan readings.
    _scanner.onReading = _handleReading;
  }

  /// Start scanning. Idempotent.
  /// Starts the background service for periodic scanning and sets up the
  /// isolate port bridge to receive readings from the background isolate.
  void start() {
    DebugLogger().i('ScanService.start() — starting background service',
        tag: 'ScanService');

    // Set up the ReceivePort to receive readings from the background isolate.
    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, AppConstants.uiIsolatePortName);
    _receivePort!.listen((message) {
      if (message is Reading) {
        _controller.add(message);
      }
    });

    // Start the background service for periodic BLE scanning.
    BackgroundService.start();
  }

  /// Restart scanning with latest settings.
  void restart() {
    try {
      BackgroundService.updateSettings();
    } catch (_) {
      // May fail in test environment.
    }
  }

  /// Force restart — used when user explicitly taps "re-scan".
  void forceRestart() {
    restart();
  }

  /// Trigger an immediate BLE scan for the devices page (nearby devices).
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

  /// Stop all scanning and clean up.
  void stop() {
    try {
      BackgroundService.stop();
    } catch (_) {
      // May fail in test environment where background service is not
      // supported (e.g. Linux/desktop test runner).
    }
    _receivePort?.close();
    _receivePort = null;
    IsolateNameServer.removePortNameMapping(AppConstants.uiIsolatePortName);
  }

  bool get isRunning => true; // Background service manages its own lifecycle.

  void _handleReading(Reading reading) {
    _repository.saveReading(reading).catchError((e) {
      DebugLogger().e('Failed to persist reading: $e', tag: 'ScanService');
    });

    _controller.add(reading);
  }

  /// Dispose the service. No further readings will be processed.
  void dispose() {
    stop();
    _controller.close();
  }
}
