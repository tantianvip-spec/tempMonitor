import 'package:equatable/equatable.dart';

/// A BLE device discovered during scanning, regardless of compatibility.
class NearbyDevice extends Equatable {
  final String deviceId;
  final String? name;
  final int rssi;
  final bool isBThomeCompatible;
  final DateTime lastSeen;

  const NearbyDevice({
    required this.deviceId,
    this.name,
    required this.rssi,
    required this.isBThomeCompatible,
    required this.lastSeen,
  });

  NearbyDevice copyWith({
    String? deviceId,
    String? name,
    int? rssi,
    bool? isBThomeCompatible,
    DateTime? lastSeen,
  }) =>
      NearbyDevice(
        deviceId: deviceId ?? this.deviceId,
        name: name ?? this.name,
        rssi: rssi ?? this.rssi,
        isBThomeCompatible: isBThomeCompatible ?? this.isBThomeCompatible,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  @override
  List<Object?> get props =>
      [deviceId, name, rssi, isBThomeCompatible, lastSeen];
}
