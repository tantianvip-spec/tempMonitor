import 'dart:typed_data';

import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

/// Custom firmware parser for ATC_PVVX sensors flashed with custom firmware.
///
/// The custom firmware broadcasts on UUID 0x181A (Environmental Sensing
/// Service). FlutterBluePlus extracts the AD structure's service data
/// (after the UUID bytes) into the serviceData map. The layout is:
///
///   Offset 0-5:   MAC address (6 bytes, correct order)
///   Offset 6-7:   Temperature sint16 LE (divide by 100)
///   Offset 8-9:   Humidity uint16 LE (divide by 100)
///   Offset 10-11: Battery voltage uint16 LE (mV)
///   Offset 12:    Battery level uint8 (0-100%)
///   (Optional: frame counter and flags may follow at offset 13+, but
///    FlutterBluePlus may strip trailing bytes — we only require 13.)
///
/// Every packet contains temperature + humidity + battery, so unlike ATC
/// original firmware there are no lifecycle-only packets — every broadcast
/// is a valid Reading.
class CustomFirmwareParser {
  /// Minimum service data length for a valid custom firmware packet.
  /// FlutterBluePlus extracts service data starting after the UUID bytes,
  /// so the actual bytes are: MAC(6) + temp(2) + humidity(1) + bat%(1) +
  /// mV(2) + counter(1) = 13 bytes.
  static const int _minDataLength = 13;

  // Physical sanity bounds — matches BThomeParser constants.
  static const double _minTemp = -40.0;
  static const double _maxTemp = 80.0;
  static const double _minHumidity = 0.0;
  static const double _maxHumidity = 100.0;

  /// Parse a custom firmware service data payload into a [Reading].
  ///
  /// Returns `null` if the payload is too short or fails validation.
  static Reading? parse(
    List<int> serviceData, {
    required String deviceId,
    required int rssi,
  }) {
    if (serviceData.length < _minDataLength) {
      DebugLogger().v(
          'CustomFirmware: service data too short '
          '(${serviceData.length} < $_minDataLength) for $deviceId',
          tag: 'CustomFirmware');
      return null;
    }

    final byteData = Uint8List.fromList(serviceData).buffer.asByteData();

    // Debug: log raw bytes to verify offsets
    DebugLogger().d(
        'CustomFirmware raw bytes (${serviceData.length}): '
        '${serviceData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} '
        'for $deviceId',
        tag: 'CustomFirmware');

    // Offset 6-7: Temperature sint16 LE (/100)
    final tempRaw = byteData.getInt16(6, Endian.little);
    final temperature = tempRaw / 100.0;

    // Offset 8-9: Humidity uint16 LE (/100)
    final humidityRaw = byteData.getUint16(8, Endian.little);
    final humidity = humidityRaw / 100.0;

    // Offset 10-11: Battery voltage uint16 LE (mV)
    // (not used in Reading model but parsed for completeness)
    // final batteryMv = byteData.getUint16(10, Endian.little);

    // Offset 12: Battery level uint8 (0-100%)
    final battery = serviceData[12];

    // Validate physical bounds.
    if (temperature < _minTemp || temperature > _maxTemp) {
      DebugLogger().d(
          'CustomFirmware: out-of-range temperature $temperature°C from $deviceId',
          tag: 'CustomFirmware');
      return null;
    }
    if (humidity < _minHumidity || humidity > _maxHumidity) {
      DebugLogger().d(
          'CustomFirmware: out-of-range humidity $humidity% from $deviceId',
          tag: 'CustomFirmware');
      return null;
    }

    DebugLogger().i(
        'CustomFirmware $deviceId: ${temperature.toStringAsFixed(1)}°C '
        '${humidity.toStringAsFixed(1)}% batt=$battery',
        tag: 'CustomFirmware');

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
