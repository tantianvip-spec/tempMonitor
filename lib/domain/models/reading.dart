import 'package:equatable/equatable.dart';

class Reading extends Equatable {
  final String deviceId;
  final double temperature;
  final double humidity;
  final int? battery;
  final int? rssi;
  final DateTime recordedAt;

  const Reading({
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    this.battery,
    this.rssi,
    required this.recordedAt,
  });

  @override
  List<Object?> get props =>
      [deviceId, temperature, humidity, battery, rssi, recordedAt];
}
