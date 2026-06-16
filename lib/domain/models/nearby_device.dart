import 'package:equatable/equatable.dart';

/// A BLE device discovered during scanning, regardless of compatibility.
class NearbyDevice extends Equatable {
  final String deviceId;
  final String? name;
  final int rssi;
  final bool isBThomeCompatible;
  final String? protocol;
  final DateTime lastSeen;

  const NearbyDevice({
    required this.deviceId,
    this.name,
    required this.rssi,
    required this.isBThomeCompatible,
    this.protocol,
    required this.lastSeen,
  });

  NearbyDevice copyWith({
    String? deviceId,
    String? name,
    int? rssi,
    bool? isBThomeCompatible,
    String? protocol,
    DateTime? lastSeen,
  }) =>
      NearbyDevice(
        deviceId: deviceId ?? this.deviceId,
        name: name ?? this.name,
        rssi: rssi ?? this.rssi,
        isBThomeCompatible: isBThomeCompatible ?? this.isBThomeCompatible,
        protocol: protocol ?? this.protocol,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  @override
  List<Object?> get props =>
      [deviceId, name, rssi, isBThomeCompatible, protocol, lastSeen];
}
