import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/bthome_parser.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class BleScanner {
  final _lastSeen = <String, DateTime>{};
  static const _debounceDuration = Duration(seconds: 1);
  DateTime? _lastBluetoothOffLog;
  bool _initialized = false;
  bool _scanning = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await FlutterBluePlus.adapterState.first;
    _initialized = true;
  }

  /// Scan for BLE devices and notify [onReading] for each valid BThome
  /// reading found. Runs for [timeout] duration then stops.
  ///
  /// Safe to call while a previous scan is still running — the old scan
  /// is stopped first.
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

    final scanTimeout = timeout ?? const Duration(seconds: 15);
    _scanning = true;

    try {
      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
      );

      // Wait for the scan to complete (flutter_blue_plus auto-stops
      // after the timeout, so just wait that long).
      await Future.delayed(scanTimeout + const Duration(seconds: 1));
    } finally {
      _scanning = false;
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      // Process whatever results came in during the scan window.
      // flutter_blue_plus accumulates results in lastScanResults.
      final results = FlutterBluePlus.lastScanResults;
      for (final device in results) {
        final reading = _tryParseResult(device);
        if (reading != null) {
          onReading?.call(reading);
        }
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

  Reading? _tryParseResult(ScanResult result) {
    final deviceId = result.device.remoteId.str;
    final now = DateTime.now();
    final lastSeen = _lastSeen[deviceId];
    if (lastSeen != null && now.difference(lastSeen) < _debounceDuration) {
      return null;
    }

    final serviceData = result.advertisementData.serviceData;
    final guid = Guid(AppConstants.bthomeServiceUuid);
    final bytes = serviceData[guid];

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    try {
      final reading = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: result.rssi,
      );
      _lastSeen[deviceId] = now;
      DebugLogger().i(
          'Found BThome device $deviceId: ${reading.temperature}°C ${reading.humidity}%',
          tag: 'BleScanner');
      return reading;
    } on BThomeParseException catch (e) {
      DebugLogger().w('Failed to parse $deviceId: $e', tag: 'BleScanner');
      return null;
    }
  }
}
