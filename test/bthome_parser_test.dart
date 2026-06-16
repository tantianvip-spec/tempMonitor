import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/services/bthome_parser.dart';

void main() {
  group('BThomeParser', () {
    const deviceId = 'A4:C1:38:00:00:01';
    const rssi = -65;

    test('parses temperature and humidity from plain BThome v2 packet', () {
      // header 0x40 = unencrypted, trigger-based
      // 0x02 temperature, int16 LE 0x09C4 = 2500 → 25.00°C
      // 0x03 humidity,    uint16 LE 0x1770 = 6000 → 60.00%
      final bytes = [0x40, 0x02, 0xC4, 0x09, 0x03, 0x70, 0x17];

      final result = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(result.deviceId, deviceId);
      expect(result.temperature, closeTo(25.00, 0.01));
      expect(result.humidity, closeTo(60.00, 0.01));
      expect(result.rssi, rssi);
    });

    test('captures battery alongside temperature and humidity', () {
      // header, battery=100, temperature=25.00°C, humidity=60.00%
      final bytes = [
        0x40,
        0x01, 0x64, // battery 100%
        0x02, 0xC4, 0x09, // temp 25.00
        0x03, 0x70, 0x17, // humidity 60.00
      ];

      final result =
          BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi);

      expect(result.battery, 100);
      expect(result.temperature, closeTo(25.00, 0.01));
      expect(result.humidity, closeTo(60.00, 0.01));
    });

    test('rejects packet missing humidity (battery-only is not a Reading)', () {
      // Real BThome devices emit battery-only lifecycle packets; those
      // are not sensor Readings and must not be persisted as one.
      final bytes = [0x40, 0x01, 0x64];
      expect(
        () => BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi),
        throwsA(isA<BThomeParseException>()),
      );
    });

    test('filters physically impossible temperature', () {
      // int16 LE 0x86A0 = -31072 → -310.72°C, far outside [-40, 80]
      final bytes = [0x40, 0x02, 0xA0, 0x86, 0x03, 0x70, 0x17];
      expect(
        () => BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi),
        throwsA(isA<BThomeParseException>()),
      );
    });

    test('filters physically impossible humidity', () {
      // uint16 LE 0x7530 = 30000 → 300.00%, outside [0, 100]
      final bytes = [0x40, 0x02, 0xC4, 0x09, 0x03, 0x30, 0x75];
      expect(
        () => BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi),
        throwsA(isA<BThomeParseException>()),
      );
    });

    test('rejects encrypted packets', () {
      final bytes = [0x41, 0x02, 0xC4, 0x09, 0x03, 0x70, 0x17];
      expect(
        () => BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi),
        throwsA(isA<BThomeParseException>()),
      );
    });

    test('skips packet_id (0x00) and still parses temperature and humidity',
        () {
      // Device A4:C1:38:3F:B9:8D emits BThome data starting with 0x00
      // (packet ID), which caused "Unknown object id" parse errors.
      // 0x40 header, 0x00 0x01 (packet_id=1), 0x02 temp, 0x03 humidity
      final bytes = [
        0x40,
        0x00, 0x01, // packet_id = 1
        0x02, 0xC4, 0x09, // temp 25.00
        0x03, 0x70, 0x17, // humidity 60.00
      ];

      final result =
          BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi);

      expect(result.temperature, closeTo(25.00, 0.01));
      expect(result.humidity, closeTo(60.00, 0.01));
    });

    test('ignores trailing unknown bytes after temp and humidity', () {
      // Some devices append vendor-specific data after the standard
      // BThome fields. If we already have temp + humidity, unknown
      // trailing object IDs should be tolerated.
      final bytes = [
        0x40,
        0x02, 0xC4, 0x09, // temp 25.00
        0x03, 0x70, 0x17, // humidity 60.00
        0xFF, 0x01, 0x02, 0x03, // unknown vendor data
      ];

      final result =
          BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi);

      expect(result.temperature, closeTo(25.00, 0.01));
      expect(result.humidity, closeTo(60.00, 0.01));
    });

    test('parses with illuminance (0x0C) before temp and humidity', () {
      // Device A4:C1:38:3F:B9:8D emits: header, packet_id, temp,
      // humidity, then illuminance (0x0C, 3 bytes). The illuminance
      // field must be correctly skipped.
      final bytes = [
        0x40,
        0x00, 0x01, // packet_id = 1
        0x02, 0xC4, 0x09, // temp 25.00
        0x03, 0x70, 0x17, // humidity 60.00
        0x0C, 0x00, 0x00, 0x01, // illuminance 1 lx
      ];

      final result =
          BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi);

      expect(result.temperature, closeTo(25.00, 0.01));
      expect(result.humidity, closeTo(60.00, 0.01));
    });

    test('rejects ATC 0x0C-only packet (no standard temp/humidity)', () {
      // Real ATC_PVVX packet from A4:C1:38:3F:B9:8D:
      //   40 00 6e 0c 9e 0b 10 00 11 01
      // 0x40 = header
      // 0x00 0x6e = packet_id
      // 0x0C 0x9e 0x0b 0x10 = illuminance (uint24 LE = 0x100b9e lx)
      // 0x00 0x11 = packet_id (second occurrence)
      // 0x01 = battery 1%
      //
      // This packet has no standard 0x02/0x03 temp/humidity objects,
      // so it must be rejected as a lifecycle-only packet.
      final bytes = [
        0x40,
        0x00, 0x6E, // packet_id = 110
        0x0C, 0x9E, 0x0B, 0x10, // illuminance only
      ];

      expect(
        () => BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi),
        throwsA(isA<BThomeParseException>()),
      );
    });

    test('parses standard-format 25.5C / 80.8% (real ATC sensor data)', () {
      // Real ATC_PVVX standard-format packet:
      //   40 00 01 02 f5 09 03 8b 1f
      // 0x40 = header
      // 0x00 0x01 = packet_id = 1
      // 0x02 0xf5 0x09 = temperature int16 LE 0x09F5 = 2549 -> 25.49C
      // 0x03 0x8b 0x1f = humidity uint16 LE 0x1F8B = 8075 -> 80.75%
      final bytes = [
        0x40,
        0x00, 0x01, // packet_id = 1
        0x02, 0xF5, 0x09, // temp 25.41C
        0x03, 0x8B, 0x1F, // humidity 80.75%
      ];

      final result =
          BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi);

      expect(result.temperature, closeTo(25.49, 0.01));
      expect(result.humidity, closeTo(80.75, 0.01));
    });
  });
}
