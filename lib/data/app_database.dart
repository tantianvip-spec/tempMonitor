import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/devices_dao.dart';
import 'daos/readings_dao.dart';
import 'daos/settings_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Devices, Readings, Settings],
  daos: [DevicesDao, ReadingsDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor. Pass `NativeDatabase.memory()` (or any
  /// other [QueryExecutor]) to run against an in-memory SQLite instance
  /// without needing the Flutter platform binding or path_provider.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // Version 2: temperature and humidity became nullable.
          // SQLite ALTER TABLE doesn't support dropping NOT NULL on a column,
          // so we recreate the table.
          await m.alterTable(TableMigration(readings));
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'temp_monitor_database');
  }
}
