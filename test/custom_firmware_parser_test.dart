import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/services/custom_firmware_parser.dart';

void main() {
  group('CustomFirmwareParser', () {
    const deviceId = 'A4:C1:38:3F:B9:8D';
    const rssi = -65;

    test('parses temperature, humidity and battery from service data', () {
      // Service data layout (13 bytes, as extracted by FlutterBluePlus):
      //   Offset 0-5:   MAC = A4:C1:38:3F:B9:8D
      //   Offset 6-7:   Temperature sint16 LE = 0x0A32 → 2610 → 26.10°C
      //   Offset 8-9:   Humidity uint16 LE = 0x1388 → 5000 → 50.00%
      //   Offset 10-11: Battery voltage uint16 LE = 0x0D48 → 3400 mV
      //   Offset 12:    Battery level uint8 = 95 → 95%
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D, // MAC
        0x32, 0x0A, // temp 26.10°C
        0x88, 0x13, // humidity 50.00%
        0x48, 0x0D, // 3400 mV
        95,         // battery 95%
      ];

      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(reading, isNotNull);
      expect(reading!.deviceId, deviceId);
      expect(reading.temperature, closeTo(26.10, 0.01));
      expect(reading.humidity, closeTo(50.00, 0.01));
      expect(reading.battery, 95);
      expect(reading.rssi, rssi);
    });

    test('parses negative temperature', () {
      // Temperature sint16 LE = 0xFED4 → -300 → -3.00°C
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D,
        0xD4, 0xFE, // temp -3.00°C
        0x88, 0x13, // humidity 50.00%
        0x48, 0x0D,
        90,
      ];

      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(reading, isNotNull);
      expect(reading!.temperature, closeTo(-3.00, 0.01));
    });

    test('returns null for too-short payload', () {
      final bytes = <int>[0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D, 0x32, 0x0A];
      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );
      expect(reading, isNull);
    });

    test('returns null for out-of-range temperature', () {
      // Temperature sint16 LE = 0x4E20 → 20000 → 200°C (above 80)
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D,
        0x20, 0x4E, // temp 200°C
        0x88, 0x13,
        0x48, 0x0D,
        90,
      ];

      final reading = CustomFirmwareParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );
      expect(reading, isNull);
    });

    test('returns null for out-of-range humidity', () {
      // Humidity uint16 LE = 0x4E20 → 20000 → 200.00% (above 100)
      final bytes = <int>[
        0xA4, 0xC1, 0x38, 0x3F, 0xB9, 0x8D,
        0x32, 0x0A, // temp 26.10°C
        0x20, 0x4E, // humidity 200.00% — invalid
        0x48, 0x0D,
        90,
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
