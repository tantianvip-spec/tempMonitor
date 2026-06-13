import 'package:equatable/equatable.dart';

class ThresholdState extends Equatable {
  final bool tempBreached;
  final bool humidityBreached;
  final bool justBecameBreached;
  final bool justRecovered;

  const ThresholdState({
    this.tempBreached = false,
    this.humidityBreached = false,
    this.justBecameBreached = false,
    this.justRecovered = false,
  });

  bool get anyBreached => tempBreached || humidityBreached;

  @override
  List<Object?> get props =>
      [tempBreached, humidityBreached, justBecameBreached, justRecovered];
}

class ThresholdEngine {
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;

  bool _wasBreached = false;

  ThresholdEngine({
    required this.tempMin,
    required this.tempMax,
    required this.humidityMin,
    required this.humidityMax,
  });

  ThresholdState evaluate({
    required double? temperature,
    required double? humidity,
  }) {
    final tempBreached = temperature != null &&
        (temperature < tempMin || temperature > tempMax);
    final humidityBreached = humidity != null &&
        (humidity < humidityMin || humidity > humidityMax);
    final currentlyBreached = tempBreached || humidityBreached;

    final justBecameBreached = !_wasBreached && currentlyBreached;
    final justRecovered = _wasBreached && !currentlyBreached;

    _wasBreached = currentlyBreached;

    return ThresholdState(
      tempBreached: tempBreached,
      humidityBreached: humidityBreached,
      justBecameBreached: justBecameBreached,
      justRecovered: justRecovered,
    );
  }
}
