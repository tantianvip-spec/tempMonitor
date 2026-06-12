import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/bthome_parser.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class BleScanner {
  final _lastSeen = <String, DateTime>{};
  static const _debounceDuration = Duration(seconds: 1);

  Stream<Reading> scan({Duration? timeout}) async* {
    if (!await FlutterBluePlus.isSupported) {
      DebugLogger().e('BLE not supported on this device', tag: 'BleScanner');
      return;
    }

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      DebugLogger().e('Bluetooth is not enabled', tag: 'BleScanner');
      return;
    }

    await FlutterBluePlus.startScan(
      withServices: [Guid(AppConstants.bthomeServiceUuid)],
      timeout: timeout ?? const Duration(seconds: 15),
    );

    await for (final result in FlutterBluePlus.scanResults) {
      for (final device in result) {
        final reading = _tryParseResult(device);
        if (reading != null) {
          yield reading;
        }
      }
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

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
      DebugLogger().d(
          'Parsed $deviceId: ${reading.temperature}°C ${reading.humidity}%',
          tag: 'BleScanner');
      return reading;
    } on BThomeParseException catch (e) {
      DebugLogger().w('Failed to parse $deviceId: $e', tag: 'BleScanner');
      return null;
    }
  }
}
