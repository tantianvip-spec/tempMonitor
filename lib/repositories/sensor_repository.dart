import 'package:drift/drift.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/domain/models/device.dart' as domain;
import 'package:temp_monitor/domain/models/reading.dart' as domain;
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class SensorRepository {
  final AppDatabase _db;

  SensorRepository(this._db);

  /// Internal constructor for testing subclasses that don't use a real DB.
  /// Subclasses must override all methods that access [_db].
  SensorRepository._internal() : _db = _unusedDb();

  static AppDatabase _unusedDb() {
    throw UnimplementedError('Use a real AppDatabase or override methods');
  }

  Stream<List<domain.Device>> watchAllDevices() {
    final query = _db.select(_db.devices)
      ..orderBy([
        (d) => OrderingTerm(
              expression: d.lastSeenAt,
              mode: OrderingMode.desc,
            )
      ]);
    return query.watch().map((rows) => rows.map(_mapDevice).toList());
  }

  Future<List<domain.Device>> getAllDevices() async {
    final rows = await _db.select(_db.devices).get();
    return rows.map(_mapDevice).toList();
  }

  Future<void> saveReading(domain.Reading reading) async {
    final existing = await _db.devicesDao.getDeviceById(reading.deviceId);
    await _db.devicesDao.upsertDevice(
      DevicesCompanion(
        id: Value(reading.deviceId),
        name: Value(existing?.name ?? reading.deviceId),
        createdAt: Value(
            existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch),
        lastSeenAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    await _db.readingsDao.insertReading(
      ReadingsCompanion(
        deviceId: Value(reading.deviceId),
        temperature: Value<double?>(reading.temperature),
        humidity: Value<double?>(reading.humidity),
        battery: Value<int?>(reading.battery),
        rssi: Value<int?>(reading.rssi),
        recordedAt: Value(reading.recordedAt.millisecondsSinceEpoch),
      ),
    );

    await _cleanupOldData();
    DebugLogger().i(
      'Saved reading: ${reading.temperature?.toStringAsFixed(1) ?? "?"}°C, '
      '${reading.humidity?.toStringAsFixed(1) ?? "?"}%',
      tag: 'Repository',
    );
  }

  Future<List<domain.Reading>> getReadingsForDevice(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.readingsDao
        .getReadingsForDevice(deviceId, from: from, to: to);
    return rows.map(_mapReading).toList();
  }

  Future<domain.Reading?> getLatestReading(String deviceId) async {
    final row = await _db.readingsDao.getLatestReading(deviceId);
    return row == null ? null : _mapReading(row);
  }

  Future<void> renameDevice(String deviceId, String name) async {
    await _db.devicesDao.upsertDevice(
      DevicesCompanion(
        id: Value(deviceId),
        name: Value(name),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> addDevice(String deviceId, {String? name}) async {
    await _db.devicesDao.upsertDevice(
      DevicesCompanion(
        id: Value(deviceId),
        name: Value(name ?? deviceId),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        lastSeenAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    DebugLogger().i('Added device: ${name ?? deviceId}', tag: 'Repository');
  }

  Future<void> _cleanupOldData() async {
    const days = AppConstants.defaultRetentionDays;
    final cutoff = DateTime.now().subtract(const Duration(days: days));
    final deleted = await _db.readingsDao.deleteReadingsBefore(cutoff);
    if (deleted > 0) {
      DebugLogger().i('Cleaned up $deleted old readings', tag: 'Repository');
    }
  }

  domain.Device _mapDevice(Device row) => domain.Device(
        id: row.id,
        name: row.name,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        lastSeenAt: row.lastSeenAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.lastSeenAt!),
      );

  domain.Reading _mapReading(Reading row) => domain.Reading(
        deviceId: row.deviceId,
        temperature: row.temperature,
        humidity: row.humidity,
        battery: row.battery,
        rssi: row.rssi,
        recordedAt:
            DateTime.fromMillisecondsSinceEpoch(row.recordedAt).toUtc(),
      );
}
