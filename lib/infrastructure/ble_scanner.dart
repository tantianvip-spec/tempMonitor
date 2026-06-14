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
        DebugLogger().w(
            'Bluetooth adapter turned off, re-initializing',
            tag: 'BleScanner');
        _initialized = false;
      } else {
        return;
      }
    }
    DebugLogger().d(
        'Waiting for Bluetooth adapter state... '
        '(current: ${FlutterBluePlus.adapterStateNow.name})',
        tag: 'BleScanner');
    await FlutterBluePlus.adapterState
        .firstWhere((s) => s != BluetoothAdapterState.unknown);
    DebugLogger().i(
        'Bluetooth adapter ready: ${FlutterBluePlus.adapterStateNow.name}',
        tag: 'BleScanner');
    _initialized = true;
  }

  /// Run one scan window of [duration]. Emits [ScanResultBundle] to
  /// [scanResults] when done.
  ///
  /// When [knownDeviceIds] is provided and non-empty, scan results that don't
  /// match a known device ID are filtered out. This avoids emitting readings
  /// for sensors the user hasn't added yet.
  ///
  /// The scan always filters by [AppConstants.bthomeServiceUuid] at the OS
  /// level via [FlutterBluePlus.startScan]'s `withServices` parameter, so
  /// only BThome-compatible devices trigger callbacks — non-BLE-thermometer
  /// devices (soundbars, lights, etc.) are never reported by the Bluetooth
  /// controller.
  /// Run a scan window for device discovery. Reports ALL nearby devices
  /// (not just known ones), used by the scan drawer to find new sensors.
  Future<void> scanForDiscovery({Duration? timeout}) async {
    await _runScanWindow(
      timeout: timeout,
      knownDeviceIds: null,
    );
  }

  /// Run one scan window for normal monitoring. When [knownDeviceIds] is
  /// provided and non-empty, results that don't match are filtered out.
  Future<void> scan({Duration? timeout, Set<String>? knownDeviceIds}) async {
    await _runScanWindow(
      timeout: timeout,
      knownDeviceIds: knownDeviceIds,
    );
  }

  /// Tracks which known devices have had temperature and/or humidity
  /// received in the current scan window. Used by [startDynamicScan] to
  /// early-stop once every known device has both values.
  ///
  /// Reset at the start of each dynamic scan tick.
  final _knownDeviceComplete = <String, _DeviceDataState>{};

  /// Start a dynamic scan window: scan until every [knownDeviceIds] has
  /// contributed both temperature AND humidity, or [timeout] elapses,
  /// whichever comes first. Reports ALL nearby devices and accumulated
  /// BThome readings on completion.
  Future<void> startDynamicScan({
    Duration? timeout,
    required Set<String> knownDeviceIds,
  }) async {
    final actualTimeout = timeout ?? const Duration(seconds: 60);
    await _runScanWindow(
      timeout: actualTimeout,
      knownDeviceIds: knownDeviceIds,
      dynamicCompletion: true,
    );
  }

  /// Shared scan-window implementation.
  ///
  /// When [dynamicCompletion] is true and [knownDeviceIds] is non-empty,
  /// the scan stops as soon as every known device has produced both a
  /// temperature AND a humidity reading. Otherwise (or when there are no
  /// known devices), the scan runs for the full [timeout].
  Future<void> _runScanWindow({
    Duration? timeout,
    Set<String>? knownDeviceIds,
    bool dynamicCompletion = false,
  }) async {
    // If a scan is already in progress, skip this tick rather than
    // interrupting it. Without this guard, a fast Timer (~5s) overlaps
    // with the scan window (~4s scan + ~1s buffer = ~5s total), causing
    // each tick to stopScan() the previous one — no scan ever completes.
    if (_scanning) {
      DebugLogger().d('Scan already in progress, skipping tick',
          tag: 'BleScanner');
      return;
    }

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

    final scanTimeout = timeout ?? const Duration(seconds: 4);
    final knownIds = knownDeviceIds;
    final hasKnownFilter = knownIds != null && knownIds.isNotEmpty;
    final useDynamic = dynamicCompletion && hasKnownFilter;
    _scanning = true;

    DebugLogger().d(
        'Scan started (timeout: ${scanTimeout.inSeconds}s, '
        'filterByKnown: $hasKnownFilter'
        '${useDynamic ? ", dynamic: true" : ""})',
        tag: 'BleScanner');

    // Real-time listener for nearby devices display and BThome accumulation.
    final nearbyDevices = <NearbyDevice>[];
    final bthomeReadings = <Reading>[];
    StreamSubscription? rtSub;
    int totalResultsSeen = 0;

    // When dynamic completion is enabled, track per-device state.
    if (useDynamic) {
      _knownDeviceComplete.clear();
      for (final id in knownIds) {
        _knownDeviceComplete[id] = _DeviceDataState();
      }
    }

    final completer = Completer<void>();
    Timer? safetyTimer;

    try {
      rtSub = FlutterBluePlus.scanResults.listen((results) {
        final now = DateTime.now();
        totalResultsSeen += results.length;
        for (final result in results) {
          final deviceId = result.device.remoteId.str;
          final rssi = result.rssi;
          final name = result.device.advName.isNotEmpty
              ? result.device.advName
              : '(unnamed)';
          final hasServiceData =
              result.advertisementData.serviceData.isNotEmpty;

          DebugLogger().v(
              'Scan result: $name ($deviceId) RSSI=$rssi '
              'serviceData=${hasServiceData ? "yes" : "no"} '
              'advDataLen=${result.advertisementData.manufacturerData.length}',
              tag: 'BleScanner');

          _updateNearby(result, now, nearbyDevices);

          // Accumulate BThome data and, when using dynamic completion,
          // track which devices have temp/humidity so we can early-stop.
          final newReadings = <Reading>[];
          _accumulateBThome(result, now, bthomeReadings,
              outNewReadings: newReadings);
          if (useDynamic && newReadings.isNotEmpty) {
            _updateDeviceCompletionState(newReadings);
            if (_allDevicesComplete()) {
              DebugLogger().d(
                  'All known devices have temp + humidity — stopping scan early',
                  tag: 'BleScanner');
              if (!completer.isCompleted) completer.complete();
            }
          }
        }
      });

      // Start scan. When monitoring known devices, pass their MAC addresses
      // to withRemoteIds so the BLE controller filters at the OS level —
      // only broadcasts from these devices trigger callbacks, avoiding
      // hundreds of irrelevant packets from soundbars, lights, etc.
      // We do NOT use withServices here because ATC_PVVX sensors include
      // the BThome UUID only in the serviceData map of the advertisement,
      // not in the advertised service UUIDs list — withServices would
      // silently drop our sensors.
      final remoteIds = hasKnownFilter ? knownIds.toList() : <String>[];
      DebugLogger().d(
          'Starting BLE scan withRemoteIds: ${remoteIds.isEmpty ? "(none)" : remoteIds.join(", ")}',
          tag: 'BleScanner');
      await FlutterBluePlus.startScan(withRemoteIds: remoteIds);

      // Wait for either completion (all devices have temp+humidity) or
      // timeout. The safety timer prevents the scan from running forever
      // if a device never sends one of the values.
      if (useDynamic) {
        safetyTimer = Timer(scanTimeout, () {
          DebugLogger().d(
              'Dynamic scan timeout reached (${scanTimeout.inSeconds}s)',
              tag: 'BleScanner');
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;
        safetyTimer.cancel();
      } else {
        await Future.delayed(scanTimeout);
      }
    } finally {
      _scanning = false;
      safetyTimer?.cancel();
      await rtSub?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      _knownDeviceComplete.clear();
    }

    DebugLogger().d(
        'Scan finished: $totalResultsSeen results, '
        '${bthomeReadings.length} BThome readings, '
        '${nearbyDevices.length} unique devices'
        '${useDynamic ? " (dynamic)" : ""}',
        tag: 'BleScanner');

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

  /// Update per-device completion state after new readings arrive.
  void _updateDeviceCompletionState(List<Reading> newReadings) {
    for (final reading in newReadings) {
      final state = _knownDeviceComplete[reading.deviceId];
      if (state == null) continue;
      if (reading.temperature != null) state.hasTemperature = true;
      if (reading.humidity != null) state.hasHumidity = true;
    }
  }

  /// Check whether every known device in the current dynamic scan has
  /// both temperature and humidity.
  bool _allDevicesComplete() {
    return _knownDeviceComplete.values
        .every((state) => state.hasTemperature && state.hasHumidity);
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
  ///
  /// When [outNewReadings] is provided, newly parsed readings are appended
  /// to it so callers can track which devices just got temp/humidity data
  /// (used for dynamic scan window early-stop).
  void _accumulateBThome(
    ScanResult result,
    DateTime now,
    List<Reading> bthomeReadings, {
    List<Reading>? outNewReadings,
  }) {
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
      outNewReadings?.add(reading);
      DebugLogger().i(
          'BThome $deviceId: '
          '${reading.temperature?.toStringAsFixed(1) ?? "?"}°C '
          '${reading.humidity?.toStringAsFixed(1) ?? "?"}%',
          tag: 'BleScanner');
      return;
    } on BThomeParseException catch (e) {
      // Fall through to manual extraction below.
      DebugLogger().v(
          'BThomeParser rejected $deviceId packet: $e — trying manual fallback',
          tag: 'BleScanner');
    }

    // Manual fallback for packets the parser can't handle.
    _mergePartial(bytes, deviceId, result.rssi, now, bthomeReadings,
        outNewReadings: outNewReadings);
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
    List<Reading> bthomeReadings, {
    List<Reading>? outNewReadings,
  }) {
    if (bytes.isEmpty) return;

    final header = bytes[0];
    if ((header & 0x01) != 0) return; // encrypted, skip

    DebugLogger().v(
        'MergePartial from $deviceId: '
        '${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        tag: 'BleScanner');

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
          // ATC_PVVX firmware sometimes uses object 0x0C (standard BThome:
          // illuminance uint24) in its non-standard encoding. Previous
          // versions of this parser attempted to extract temperature and
          // humidity from the 0x0C payload bytes, but this produced wrong
          // values (e.g. 29.7C vs real 25.5C). The correct temperature
          // and humidity come in separate standard-format packets (0x02/
          // 0x03). So we skip 0x0C entirely and let the parser fall
          // through.
          // No special extraction needed.
          offset += dataLen;
          if (objectId >= 0x80) offset += 1;
      }
    }

    // If this packet has no temperature or humidity data, skip it.
    // Battery-only lifecycle packets are not useful readings.
    if (temperature == null && humidity == null) return;

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
    outNewReadings?.add(reading);
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

/// Per-device state for dynamic scan window early-stop.
///
/// Tracks whether temperature and/or humidity have been received
/// for a known device in the current scan tick. When both are true
/// for every known device, the scan stops early.
class _DeviceDataState {
  bool hasTemperature = false;
  bool hasHumidity = false;
}
