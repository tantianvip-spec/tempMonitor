import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/services/threshold_engine.dart';

void main() {
  group('ThresholdEngine', () {
    test('returns breached when temperature exceeds max', () {
      final engine = ThresholdEngine(
        tempMin: 0,
        tempMax: 30,
        humidityMin: 20,
        humidityMax: 80,
      );
      final state = engine.evaluate(temperature: 35, humidity: 50);
      expect(state.tempBreached, true);
      expect(state.humidityBreached, false);
      expect(state.justBecameBreached, true);
    });

    test('does not repeat notification while still breached', () {
      final engine = ThresholdEngine(
        tempMin: 0,
        tempMax: 30,
        humidityMin: 20,
        humidityMax: 80,
      );
      engine.evaluate(temperature: 35, humidity: 50);
      final state2 = engine.evaluate(temperature: 36, humidity: 50);
      expect(state2.justBecameBreached, false);
    });

    test('sends recovery notification when back to normal', () {
      final engine = ThresholdEngine(
        tempMin: 0,
        tempMax: 30,
        humidityMin: 20,
        humidityMax: 80,
      );
      engine.evaluate(temperature: 35, humidity: 50);
      final state = engine.evaluate(temperature: 25, humidity: 50);
      expect(state.justRecovered, true);
      expect(state.justBecameBreached, false);
    });
  });
}
