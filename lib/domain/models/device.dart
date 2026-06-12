import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  const Device({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastSeenAt,
  });

  Device copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  }) =>
      Device(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );

  @override
  List<Object?> get props => [id, name, createdAt, lastSeenAt];
}
