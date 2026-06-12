import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// `sqlite3` ships transitively via `drift`; we depend on it only inside this
// test to point the loader at the SONAME-versioned Linux library.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/open.dart';
import 'package:temp_monitor/data/app_database.dart' show AppDatabase;
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

void main() {
  setUpAll(() {
    // The default sqlite3 loader looks for `libsqlite3.so` on Linux, but
    // many distros only ship the SONAME-versioned `libsqlite3.so.0`.
    // Point the loader at the versioned file so in-memory tests work
    // without needing `sqlite3_flutter_libs` or a dev-package install.
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  group('SensorRepository', () {
    late AppDatabase db;
    late SensorRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = SensorRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('saves reading and retrieves latest', () async {
      final reading = Reading(
        deviceId: 'device-1',
        temperature: 25.0,
        humidity: 60.0,
        recordedAt: DateTime.now().toUtc(),
      );

      await repo.saveReading(reading);
      final latest = await repo.getLatestReading('device-1');

      expect(latest, isNotNull);
      expect(latest!.temperature, 25.0);
      expect(latest.humidity, 60.0);
    });

    test('retrieves readings within a time range', () async {
      final now = DateTime.now().toUtc();
      for (var i = 0; i < 5; i++) {
        await repo.saveReading(Reading(
          deviceId: 'device-1',
          temperature: 20.0 + i,
          humidity: 50.0 + i,
          recordedAt: now.subtract(Duration(minutes: i)),
        ));
      }

      final readings = await repo.getReadingsForDevice(
        'device-1',
        from: now.subtract(const Duration(minutes: 10)),
        to: now.add(const Duration(minutes: 1)),
      );

      expect(readings.length, 5);
    });

    test('upsertDevice keeps existing createdAt when only lastSeenAt changes',
        () async {
      final first = Reading(
        deviceId: 'device-1',
        temperature: 25.0,
        humidity: 60.0,
        recordedAt: DateTime.now().toUtc(),
      );
      await repo.saveReading(first);
      final devicesBefore = await db.devicesDao.getAllDevices();
      final createdAtBefore = devicesBefore.single.createdAt;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.saveReading(first);
      final devicesAfter = await db.devicesDao.getAllDevices();
      expect(devicesAfter.single.createdAt, createdAtBefore,
          reason: 'saveReading should not overwrite createdAt on every packet');
    });
  });
}
