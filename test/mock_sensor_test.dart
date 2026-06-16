import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/infrastructure/mock_sensor.dart';

void main() {
  group('MockSensor', () {
    test('emits readings on the requested interval', () async {
      final sensor = MockSensor();
      final readings = await sensor
          .readings(
              deviceId: 'mock-1', interval: const Duration(milliseconds: 10))
          .take(3)
          .toList();

      expect(readings, hasLength(3));
      for (final r in readings) {
        expect(r.deviceId, 'mock-1');
        expect(r.temperature, inInclusiveRange(-10.0, 50.0));
        expect(r.humidity, inInclusiveRange(0.0, 100.0));
        expect(r.battery, isNotNull);
        expect(r.battery, inInclusiveRange(0, 100));
      }
    });

    test('values evolve gradually rather than jumping', () async {
      final sensor = MockSensor();
      final readings = await sensor
          .readings(
              deviceId: 'mock-1', interval: const Duration(milliseconds: 5))
          .take(5)
          .toList();

      // The random walk step is ±0.3°C/±0.6%; consecutive deltas should
      // never exceed the maximum step magnitude.
      for (var i = 1; i < readings.length; i++) {
        expect((readings[i].temperature! - readings[i - 1].temperature!).abs(),
            lessThanOrEqualTo(0.6));
        expect((readings[i].humidity! - readings[i - 1].humidity!).abs(),
            lessThanOrEqualTo(1.2));
      }
    });
  });
}