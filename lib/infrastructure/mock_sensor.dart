import 'dart:math';

import 'package:temp_monitor/domain/models/reading.dart';

/// Produces a stream of simulated [Reading] values — a random walk
/// around room-temperature baselines — so the app can be exercised
/// without real BLE hardware.
///
/// Values stay within plausible BThome-v2 ranges:
///   temperature  [-10, 50] °C
///   humidity     [  5, 95] %
///   battery      70–100 %
///   RSSI         -70 to -50 dBm
class MockSensor {
  final _random = Random();
  double _temperature = 25.0;
  double _humidity = 58.0;

  Stream<Reading> readings({
    required String deviceId,
    required Duration interval,
  }) {
    return Stream.periodic(interval, (_) {
      _temperature += (_random.nextDouble() - 0.5) * 0.6;
      _temperature = _temperature.clamp(-10.0, 50.0);
      _humidity += (_random.nextDouble() - 0.5) * 1.2;
      _humidity = _humidity.clamp(5.0, 95.0);

      return Reading(
        deviceId: deviceId,
        temperature: double.parse(_temperature.toStringAsFixed(2)),
        humidity: double.parse(_humidity.toStringAsFixed(2)),
        battery: 70 + _random.nextInt(31),
        rssi: -70 + _random.nextInt(21),
        recordedAt: DateTime.now().toUtc(),
      );
    });
  }
}