import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'devices_dao.g.dart';

@DriftAccessor(tables: [Devices])
class DevicesDao extends DatabaseAccessor<AppDatabase> with _$DevicesDaoMixin {
  DevicesDao(super.db);

  Future<List<Device>> getAllDevices() => select(devices).get();

  Future<Device?> getDeviceById(String id) =>
      (select(devices)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<int> upsertDevice(DevicesCompanion companion) =>
      into(devices).insertOnConflictUpdate(companion);

  Future<int> deleteDevice(String id) =>
      (delete(devices)..where((d) => d.id.equals(id))).go();
}
