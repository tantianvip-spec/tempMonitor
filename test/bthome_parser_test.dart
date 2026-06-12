import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/services/bthome_parser.dart';

void main() {
  group('BThomeParser', () {
    const deviceId = 'A4:C1:38:00:00:01';
    const rssi = -65;

    test('parses temperature and humidity from plain BThome v2 packet', () {
      // BThome v2: [0x40, 0x02, 0x34, 0x12, 0x03, 0x30, 0x75]
      // 0x40 = BThome v2 unencrypted, trigger-based advertising
      // 0x02 temperature, 2 bytes, 0x1234 -> 46.60°C
      // 0x03 humidity, 2 bytes, 0x7530 -> 300.00%
      final bytes = [0x40, 0x02, 0x34, 0x12, 0x03, 0x30, 0x75];

      final result = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(result.deviceId, deviceId);
      expect(result.temperature, closeTo(46.60, 0.01));
      expect(result.humidity, closeTo(300.00, 0.01));
      expect(result.rssi, rssi);
    });

    test('parses battery object id', () {
      final bytes = [0x40, 0x01, 0x64, 0x02, 0x00, 0x00];
      final result = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(result.battery, 100);
      expect(result.temperature, closeTo(0.0, 0.01));
    });

    test('filters physically impossible temperature', () {
      final bytes = [0x40, 0x02, 0xA0, 0x86, 0x01, 0x01]; // ~344.64°C
      expect(
        () => BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi),
        throwsA(isA<BThomeParseException>()),
      );
    });
  });
}
