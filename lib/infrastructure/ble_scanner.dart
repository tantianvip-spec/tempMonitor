import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/domain/models/nearby_device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/bthome_parser.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

/// Result of a single BLE scan tick — all nearby devices + any new
/// BThome readings parsed from the scan window.
class ScanResultBundle {
  final List<NearbyDevice> nearbyDevices;
  final List<Reading> bthomeReadings;

  const ScanResultBundle({
    required this.nearbyDevices,
    required this.bthomeReadings,
  });
}

class BleScanner {
  final _lastSeen = <String, DateTime>{};
  final _lastParseError = <String, DateTime>{};
  static const _debounceDuration = Duration(seconds: 1);
  static const _parseErrorDebounce = Duration(seconds: 30);
  DateTime? _lastBluetoothOffLog;
  bool _initialized = false;
  bool _scanning = false;

  /// Stream of scan results emitted after each scan window.
  final _scanResultsController =
      StreamController<ScanResultBundle>.broadcast();
  Stream<ScanResultBundle> get scanResults => _scanResultsController.stream;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.unknown &&
          FlutterBluePlus.adapterStateNow == BluetoothAdapterState.off) {
        _initialized = false;
      } else {
        return;
      }
    }
    await FlutterBluePlus.adapterState
        .firstWhere((s) => s != BluetoothAdapterState.unknown);
    _initialized = true;
  }

  /// Run one scan window of [duration]. Emits [ScanResultBundle] to
  /// [scanResults] when done.
  Future<void> scan({Duration? timeout}) async {
    if (!await FlutterBluePlus.isSupported) {
      DebugLogger().e('BLE not supported on this device', tag: 'BleScanner');
      return;
    }

    await _ensureInitialized();

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      final now = DateTime.now();
      if (_lastBluetoothOffLog == null ||
          now.difference(_lastBluetoothOffLog!) > const Duration(seconds: 30)) {
        _lastBluetoothOffLog = now;
        DebugLogger().e(
            'Bluetooth adapter is ${FlutterBluePlus.adapterStateNow.name}',
            tag: 'BleScanner');
      }
      return;
    }

    // Stop any previous scan first.
    if (_scanning) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }

    final scanTimeout = timeout ?? const Duration(seconds: 4);
    _scanning = true;

    // Real-time listener for nearby devices display.
    final nearbyDevices = <NearbyDevice>[];
    final bthomeReadings = <Reading>[];
    StreamSubscription? rtSub;

    try {
      rtSub = FlutterBluePlus.scanResults.listen((results) {
        final now = DateTime.now();
        for (final result in results) {
          _updateNearby(result, now, nearbyDevices);
        }
      });

      await FlutterBluePlus.startScan(timeout: scanTimeout);
      await Future.delayed(scanTimeout + const Duration(seconds: 1));
    } finally {
      _scanning = false;
      await rtSub?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }

    // Parse BThome data from lastScanResults (one shot, most recent per device).
    final now = DateTime.now();
    for (final result in FlutterBluePlus.lastScanResults) {
      _parseBThome(result, now, bthomeReadings);
    }

    _scanResultsController.add(ScanResultBundle(
      nearbyDevices: nearbyDevices,
      bthomeReadings: bthomeReadings,
    ));

    for (final reading in bthomeReadings) {
      onReading?.call(reading);
    }
  }

  /// Update the nearby-devices list from a scan result (real-time display).
  void _updateNearby(
    ScanResult result,
    DateTime now,
    List<NearbyDevice> nearbyDevices,
  ) {
    final deviceId = result.device.remoteId.str;
    final serviceData = result.advertisementData.serviceData;
    final guid = Guid(AppConstants.bthomeServiceUuid);
    final bytes = serviceData[guid];
    final isBThome = bytes != null && bytes.isNotEmpty;

    final existingIdx =
        nearbyDevices.indexWhere((d) => d.deviceId == deviceId);
    final nearby = NearbyDevice(
      deviceId: deviceId,
      name:
          result.device.advName.isNotEmpty ? result.device.advName : null,
      rssi: result.rssi,
      isBThomeCompatible: isBThome,
      lastSeen: now,
    );
    if (existingIdx >= 0) {
      nearbyDevices[existingIdx] = nearby;
    } else {
      nearbyDevices.add(nearby);
    }
  }

  /// Try to parse BThome data from a single scan result.
  void _parseBThome(
    ScanResult result,
    DateTime now,
    List<Reading> bthomeReadings,
  ) {
    final deviceId = result.device.remoteId.str;
    final serviceData = result.advertisementData.serviceData;
    final guid = Guid(AppConstants.bthomeServiceUuid);
    final bytes = serviceData[guid];
    if (bytes == null || bytes.isEmpty) return;

    final lastSeen = _lastSeen[deviceId];
    if (lastSeen != null && now.difference(lastSeen) < _debounceDuration) {
      return;
    }
    try {
      final reading = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: result.rssi,
      );
      _lastSeen[deviceId] = now;
      bthomeReadings.add(reading);
      DebugLogger().i(
          'BThome $deviceId: ${reading.temperature.toStringAsFixed(2)}°C ${reading.humidity.toStringAsFixed(2)}%',
          tag: 'BleScanner');
    } on BThomeParseException catch (e) {
      final last = _lastParseError[deviceId];
      if (last == null || now.difference(last) > _parseErrorDebounce) {
        _lastParseError[deviceId] = now;
        DebugLogger().d(
            'Partial BThome packet from $deviceId: $e', tag: 'BleScanner');
      }
    }
  }

  Future<void> stopScan() async {
    _scanning = false;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Called when a valid BThome reading is parsed. Set by ScanService.
  void Function(Reading)? onReading;

  void dispose() {
    _scanResultsController.close();
  }
}
