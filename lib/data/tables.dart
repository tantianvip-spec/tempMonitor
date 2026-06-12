import 'package:drift/drift.dart';

class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
  IntColumn get lastSeenAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Readings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().references(Devices, #id)();
  RealColumn get temperature => real()();
  RealColumn get humidity => real()();
  IntColumn get battery => integer().nullable()();
  IntColumn get rssi => integer().nullable()();
  IntColumn get recordedAt => integer()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
