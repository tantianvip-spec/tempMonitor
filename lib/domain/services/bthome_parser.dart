import 'dart:typed_data';

import 'package:temp_monitor/domain/models/reading.dart';

class BThomeParseException implements Exception {
  final String message;
  BThomeParseException(this.message);
  @override
  String toString() => 'BThomeParseException: $message';
}

class BThomeParser {
  static const int _objectIdBattery = 0x01;
  static const int _objectIdTemperature = 0x02;
  static const int _objectIdHumidity = 0x03;
  static const int _objectIdTemperatureHigh = 0x2A;
  static const int _objectIdHumidityHigh = 0x2B;

  static const double _minTemp = -40.0;
  static const double _maxTemp = 80.0;

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

    double? temperature;
    double? humidity;
    int? battery;

    var offset = 1;
    final byteData = Uint8List.fromList(bytes).buffer.asByteData();

    while (offset < bytes.length) {
      final objectId = bytes[offset];
      offset++;

      switch (objectId) {
        case _objectIdBattery:
          if (offset >= bytes.length) break;
          battery = bytes[offset];
          offset++;
        case _objectIdTemperature:
        case _objectIdTemperatureHigh:
          if (offset + 1 >= bytes.length) break;
          final raw = byteData.getInt16(offset, Endian.little);
          temperature = raw * 0.01;
          offset += 2;
        case _objectIdHumidity:
        case _objectIdHumidityHigh:
          if (offset + 1 >= bytes.length) break;
          final raw = byteData.getUint16(offset, Endian.little);
          humidity = raw * 0.01;
          offset += 2;
        default:
          // Unknown object id, skip if we know length, otherwise abort.
          throw BThomeParseException('Unknown object id: 0x${objectId.toRadixString(16)}');
      }
    }

    if (temperature == null) {
      throw BThomeParseException('Missing temperature');
    }

    if (temperature < _minTemp || temperature > _maxTemp) {
      throw BThomeParseException('Temperature out of range: $temperature');
    }

    return Reading(
      deviceId: deviceId,
      temperature: temperature,
      humidity: humidity ?? 0.0,
      battery: battery,
      rssi: rssi,
      recordedAt: DateTime.now().toUtc(),
    );
  }
}
