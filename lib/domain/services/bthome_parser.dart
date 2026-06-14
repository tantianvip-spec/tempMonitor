import 'dart:typed_data';

import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class BThomeParseException implements Exception {
  final String message;
  BThomeParseException(this.message);
  @override
  String toString() => 'BThomeParseException: $message';
}

class BThomeParser {
  // ── Known object IDs ──────────────────────────────────────────
  static const int _objectIdPacketId = 0x00;
  static const int _objectIdBattery = 0x01;
  static const int _objectIdTemperature = 0x02;
  static const int _objectIdHumidity = 0x03;
  static const int _objectIdTemperatureHigh = 0x2A;
  static const int _objectIdHumidityHigh = 0x2B;

  /// BThome v2 object data lengths for IDs 0x00–0x3F.
  /// IDs outside this range either use the next byte as length (≥0x80)
  /// or are reserved. A value of 0 means unknown.
  static const _lengthTable = <int, int>{
    0x00: 1, // packet_id
    0x01: 1, // battery
    0x02: 2, // temperature (sint16)
    0x03: 2, // humidity (uint16)
    0x04: 3, // pressure
    0x05: 3, // illuminance
    0x06: 2, // mass
    0x07: 1, // count
    0x08: 3, // energy
    0x09: 1, // power
    0x0A: 2, // voltage
    0x0B: 2, // pm2.5
    0x0C: 3, // illuminance (uint24)
    0x0D: 2, // pm10
    0x0E: 2, // co2
    0x0F: 2, // tvoc
    0x10: 1, // moisture
    0x11: 2, // acceleration_x
    0x12: 2, // acceleration_y
    0x13: 2, // acceleration_z
    0x14: 2, // rotation_x
    0x15: 2, // rotation_y
    0x16: 2, // rotation_z
    0x17: 2, // distance
    0x18: 2, // gyro_x
    0x19: 2, // gyro_y
    0x1A: 2, // gyro_z
    0x2A: 2, // temperature (high res, sint16)
    0x2B: 2, // humidity (high res, uint16)
    0x2C: 3, // pressure (high res)
    0x2D: 3, // illuminance (high res)
    0x2E: 2, // co2 (high res)
    0x2F: 2, // tvoc (high res)
  };

  // Physical sanity bounds — anything outside these is treated as a
  // garbled / wrong-firmware packet and rejected so it never reaches
  // the DB or threshold engine.
  static const double _minTemp = -40.0;
  static const double _maxTemp = 80.0;
  static const double _minHumidity = 0.0;
  static const double _maxHumidity = 100.0;

  /// Returns the data length (in bytes) for [objectId], or `null` if
  /// the ID is unknown and we can't determine the length.
  static int? _objectDataLength(int objectId, List<int> bytes, int offset) {
    if (objectId < 0x40) {
      // 0x00–0x3F: fixed length from table.
      final len = _lengthTable[objectId];
      if (len != null) return len;
      // Unknown ID in this range — no way to know length.
      return null;
    }
    if (objectId < 0x80) {
      // 0x40–0x7F: no data (flag bytes).
      return 0;
    }
    // 0x80–0xFF: next byte is the data length.
    if (offset >= bytes.length) return null;
    return bytes[offset];
  }

  static Reading parse(
    List<int> bytes, {
    required String deviceId,
    required int rssi,
  }) {
    if (bytes.isEmpty) {
      throw BThomeParseException('Empty packet');
    }

    // BThome v2 first byte: bit 0 = encryption, bit 5 = trigger based.
    // For now we only support unencrypted.
    final header = bytes[0];
    if ((header & 0x01) != 0) {
      throw BThomeParseException('Encrypted BThome packets are not supported');
    }

    DebugLogger().v(
        'Parsing BThome packet from $deviceId: '
        '${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        tag: 'BThomeParser');

    double? temperature;
    double? humidity;
    int? battery;

    final byteData = Uint8List.fromList(bytes).buffer.asByteData();
    var offset = 1;

    _parseLoop:
    while (offset < bytes.length) {
      final objectId = bytes[offset];
      offset++;

      switch (objectId) {
        case _objectIdPacketId:
          // BThome v2 packet ID — 1 byte, used for deduplication.
          if (offset >= bytes.length) continue;
          offset++;
        case _objectIdBattery:
          if (offset >= bytes.length) continue;
          battery = bytes[offset];
          offset++;
        case _objectIdTemperature:
        case _objectIdTemperatureHigh:
          if (offset + 1 >= bytes.length) continue;
          final raw = byteData.getInt16(offset, Endian.little);
          temperature = raw / 100;
          offset += 2;
          if (humidity != null) break _parseLoop;
        case _objectIdHumidity:
        case _objectIdHumidityHigh:
          if (offset + 1 >= bytes.length) continue;
          final raw = byteData.getUint16(offset, Endian.little);
          humidity = raw / 100;
          offset += 2;
        default:
          // BThome v2: IDs 0x40–0x7F are 0-length (flags), IDs ≥0x80
          // are variable-length (next byte is length). For known IDs
          // in 0x00–0x3F we look up the length table; for anything else
          // we read the length from the next byte.
          final dataLen = _objectDataLength(objectId, bytes, offset);
          if (dataLen == null) {
            throw BThomeParseException(
                'Unknown object id: 0x${objectId.toRadixString(16)}');
          }
          // For variable-length IDs (≥0x80), the length byte itself
          // sits at bytes[offset] and is 1 byte; skip it too.
          offset += dataLen;
          if (objectId >= 0x80) offset += 1;
      }

      // If we already have both temp and humidity, stop — remaining
      // bytes are vendor-specific data we don't understand.
      if (temperature != null && humidity != null) break _parseLoop;
    }

    // Validate individually: if temperature was received, check it's
    // within physical bounds.
    if (temperature != null &&
        (temperature < _minTemp || temperature > _maxTemp)) {
      throw BThomeParseException('Temperature out of range: $temperature');
    }
    if (humidity != null &&
        (humidity < _minHumidity || humidity > _maxHumidity)) {
      throw BThomeParseException('Humidity out of range: $humidity');
    }

    if (temperature == null && humidity == null) {
      throw BThomeParseException(
          'No temperature or humidity data in packet');
    }

    return Reading(
      deviceId: deviceId,
      temperature: temperature,
      humidity: humidity,
      battery: battery,
      rssi: rssi,
      recordedAt: DateTime.now().toUtc(),
    );
  }
}
