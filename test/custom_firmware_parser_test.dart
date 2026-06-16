import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/services/custom_firmware_parser.dart';

void main() {
  group('CustomFirmwareParser', () {
    const deviceId = 'A4:C1:38:3F:B9:8D';
    const rssi = -65;

    test('parses temperature, humidity and battery from service data', () {
      // Service data layout (13 bytes, as extracted by FlutterBluePlus):
      //   Offset 0-5:   MAC = A4:C1:38:3F:B9:8D
      //   Offset 6-7:   Temperature int16 BE = 0x0133 → 307 → 30.7°C
      //   Offset 8:     Humidity uint8 = 62 → 62%
      //   Offset 9:     Battery level uint8 = 98 → 98%
      //   Offset 10-11: Battery voltage uint16 BE = 0x0BA9 → 2985 mV
      //   Offset 12:    Frame counter = 0x89
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D, // MAC
        0x01, 0x33, // temp 30.7°C (BE)
        62,         // humidity 62%
        98,         // battery 98%
        0x0B, 0xA9, // 2985 mV (BE)
        0x89,       // counter
      ];

      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(reading, isNotNull);
      expect(reading!.deviceId, deviceId);
      expect(reading.temperature, closeTo(30.7, 0.01));
      expect(reading.humidity, closeTo(62.0, 0.01));
      expect(reading.battery, 98);
      expect(reading.rssi, rssi);
    });

    test('parses negative temperature', () {
      // Temperature int16 BE = 0xFFCE → -50 → -5.0°C
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D,
        0xFF, 0xCE, // temp -5.0°C (BE)
        50,         // humidity 50%
        90,         // battery 90%
        0x0B, 0xA9,
        0x00,
      ];

      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(reading, isNotNull);
      expect(reading!.temperature, closeTo(-5.0, 0.01));
    });

    test('returns null for too-short payload', () {
      final bytes = <int>[0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D, 0x01, 0x33];
      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );
      expect(reading, isNull);
    });

    test('returns null for out-of-range temperature', () {
      // Temperature int16 BE = 0x03E8 → 1000 → 100.0°C (above 80)
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D,
        0x03, 0xE8, // temp 100.0°C (BE) — invalid
        50,
        90,
        0x0B, 0xA9,
        0x00,
      ];

      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );
      expect(reading, isNull);
    });

    test('returns null for out-of-range humidity', () {
      // Humidity uint8 = 101 — above 100
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D,
        0x01, 0x33, // temp 30.7°C
        101,        // humidity 101% — invalid
        90,
        0x0B, 0xA9,
        0x00,
      ];

      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );
      expect(reading, isNull);
    });
  });
}
