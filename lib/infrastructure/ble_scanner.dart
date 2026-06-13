import 'dart:async';
import 'dart:typed_data';

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

  // Physical sanity bounds — matches BThomeParser constants.
  static const double _minTemp = -40.0;
  static const double _maxTemp = 80.0;
  static const double _minHumidity = 0.0;
  static const double _maxHumidity = 100.0;

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

    // Real-time listener for nearby devices display and BThome accumulation.
    final nearbyDevices = <NearbyDevice>[];
    final bthomeReadings = <Reading>[];
    StreamSubscription? rtSub;

    try {
      rtSub = FlutterBluePlus.scanResults.listen((results) {
        final now = DateTime.now();
        for (final result in results) {
          _updateNearby(result, now, nearbyDevices);
          // Process BThome data as it arrives — accumulate partial
          // readings across multiple advertisements.
          _accumulateBThome(result, now, bthomeReadings);
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

    // Also check lastScanResults for any BThome data we might have missed.
    for (final result in FlutterBluePlus.lastScanResults) {
      _parseBThome(result, DateTime.now(), bthomeReadings);
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
          'BThome $deviceId: '
          '${reading.temperature?.toStringAsFixed(1) ?? "?"}°C '
          '${reading.humidity?.toStringAsFixed(1) ?? "?"}%',
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

  /// Accumulate BThome data from a scan result. Tries full parse first;
  /// if it succeeds (even with partial temp/humidity), emit immediately.
  /// Falls back to manual extraction for packets the parser rejects
  /// (encrypted, unknown format, etc.).
  void _accumulateBThome(
    ScanResult result,
    DateTime now,
    List<Reading> bthomeReadings,
  ) {
    final deviceId = result.device.remoteId.str;
    final serviceData = result.advertisementData.serviceData;
    final guid = Guid(AppConstants.bthomeServiceUuid);
    final bytes = serviceData[guid];
    if (bytes == null || bytes.isEmpty) return;

    // Try a full parse first — some sensors send everything in one packet.
    // Now that the parser allows partial temp/humidity, this succeeds even
    // for single-value packets like ATC_PVVX.
    try {
      final reading = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: result.rssi,
      );
      bthomeReadings.add(reading);
      DebugLogger().i(
          'BThome $deviceId: '
          '${reading.temperature?.toStringAsFixed(1) ?? "?"}°C '
          '${reading.humidity?.toStringAsFixed(1) ?? "?"}%',
          tag: 'BleScanner');
      return;
    } on BThomeParseException {
      // Fall through to manual extraction below.
    }

    // Manual fallback for packets the parser can't handle.
    _mergePartial(bytes, deviceId, result.rssi, now, bthomeReadings);
  }

  /// Extract temperature/humidity/battery from a partial BThome packet
  /// and merge with previously accumulated data. Emits a partial reading
  /// immediately whenever temperature or humidity is available — no need
  /// to wait for both, because ATC_PVVX sensors split them across
  /// separate advertisements.
  void _mergePartial(
    List<int> bytes,
    String deviceId,
    int rssi,
    DateTime now,
    List<Reading> bthomeReadings,
  ) {
    if (bytes.isEmpty) return;

    final header = bytes[0];
    if ((header & 0x01) != 0) return; // encrypted, skip

    final byteData = Uint8List.fromList(bytes).buffer.asByteData();
    double? temperature;
    double? humidity;
    int? battery;
    var offset = 1;

    while (offset < bytes.length) {
      final objectId = bytes[offset];
      offset++;

      switch (objectId) {
        case 0x00: // packet_id
          if (offset >= bytes.length) continue;
          offset++;
        case 0x01: // battery
          if (offset >= bytes.length) continue;
          battery = bytes[offset];
          offset++;
        case 0x02: // temperature
        case 0x2A: // temperature high res
          if (offset + 1 >= bytes.length) continue;
          temperature = byteData.getInt16(offset, Endian.little) / 100;
          offset += 2;
        case 0x03: // humidity
        case 0x2B: // humidity high res
          if (offset + 1 >= bytes.length) continue;
          humidity = byteData.getUint16(offset, Endian.little) / 100;
          offset += 2;
        default:
          final dataLen = _objectDataLength(objectId, bytes, offset);
          if (dataLen == null) return;
          offset += dataLen;
          if (objectId >= 0x80) offset += 1;
      }
    }

    // If this packet has no useful data (neither temp, humidity, nor
    // battery), skip it.
    if (temperature == null && humidity == null && battery == null) return;

    // Validate physical bounds before emitting.
    if (temperature != null &&
        (temperature < _minTemp || temperature > _maxTemp)) {
      DebugLogger().d(
          'Ignoring out-of-range temperature from $deviceId: $temperature',
          tag: 'BleScanner');
      return;
    }
    if (humidity != null &&
        (humidity < _minHumidity || humidity > _maxHumidity)) {
      DebugLogger().d(
          'Ignoring out-of-range humidity from $deviceId: $humidity',
          tag: 'BleScanner');
      return;
    }

    // Emit immediately with whatever we have.
    final reading = Reading(
      deviceId: deviceId,
      temperature: temperature,
      humidity: humidity,
      battery: battery,
      rssi: rssi,
      recordedAt: now.toUtc(),
    );
    bthomeReadings.add(reading);
    DebugLogger().i(
      'BThome $deviceId: ${temperature?.toStringAsFixed(1) ?? "?"}°C '
      '${humidity?.toStringAsFixed(1) ?? "?"}% (partial)',
      tag: 'BleScanner',
    );
  }

  /// BThome v2 object data length lookup.
  static int? _objectDataLength(int objectId, List<int> bytes, int offset) {
    if (objectId < 0x40) {
      final len = _lengthTable[objectId];
      if (len != null) return len;
      return null;
    }
    if (objectId < 0x80) return 0;
    if (offset >= bytes.length) return null;
    return bytes[offset];
  }

  static const _lengthTable = <int, int>{
    0x00: 1, 0x01: 1, 0x02: 2, 0x03: 2, 0x04: 3, 0x05: 3,
    0x06: 2, 0x07: 1, 0x08: 3, 0x09: 1, 0x0A: 2, 0x0B: 2,
    0x0C: 3, 0x0D: 2, 0x0E: 2, 0x0F: 2, 0x10: 1, 0x11: 2,
    0x12: 2, 0x13: 2, 0x14: 2, 0x15: 2, 0x16: 2, 0x17: 2,
    0x18: 2, 0x19: 2, 0x1A: 2,
    0x2A: 2, 0x2B: 2, 0x2C: 3, 0x2D: 3, 0x2E: 2, 0x2F: 2,
  };

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
