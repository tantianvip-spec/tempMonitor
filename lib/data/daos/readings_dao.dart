import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'readings_dao.g.dart';

@DriftAccessor(tables: [Readings])
class ReadingsDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingsDaoMixin {
  ReadingsDao(super.db);

  Future<int> insertReading(ReadingsCompanion companion) =>
      into(readings).insert(companion);

  Future<List<Reading>> getReadingsForDevice(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) {
    return (select(readings)
          ..where((r) => r.deviceId.equals(deviceId))
          ..where((r) => r.recordedAt.isBetweenValues(
                from.millisecondsSinceEpoch,
                to.millisecondsSinceEpoch,
              ))
          ..orderBy([(r) => OrderingTerm(expression: r.recordedAt)]))
        .get();
  }

  Future<int> deleteReadingsBefore(DateTime cutoff) =>
      (delete(readings)
            ..where((r) => r.recordedAt.isSmallerThanValue(
                  cutoff.millisecondsSinceEpoch,
                )))
          .go();

  Future<Reading?> getLatestReading(String deviceId) =>
      (select(readings)
            ..where((r) => r.deviceId.equals(deviceId))
            ..orderBy([
              (r) => OrderingTerm(
                    expression: r.recordedAt,
                    mode: OrderingMode.desc,
                  )
            ])
            ..limit(1))
          .getSingleOrNull();
}
