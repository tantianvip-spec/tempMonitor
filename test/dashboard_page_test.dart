import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/domain/models/device.dart' as domain;
import 'package:temp_monitor/domain/models/reading.dart' as domain;
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

/// A fake repository that returns controlled streams/lists instead of
/// hitting a real database.
class _FakeRepository extends SensorRepository {
  _FakeRepository(super.db);

  @override
  Stream<List<domain.Device>> watchAllDevices() =>
      Stream<List<domain.Device>>.value([]);

  @override
  Future<domain.Reading?> getLatestReading(String deviceId) async => null;

  @override
  Future<List<domain.Reading>> getReadingsForDevice(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) async =>
      [];
}

void main() {
  group('DashboardPage', () {
    setUpAll(() {
      if (Platform.isLinux) {
        open.overrideFor(
          OperatingSystem.linux,
          () => DynamicLibrary.open('libsqlite3.so.0'),
        );
      }
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows empty state when no devices', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _FakeRepository(db);

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<DashboardCubit>(
          create: (_) => DashboardCubit(repo),
          child: const DashboardPage(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('请添加设备'), findsOneWidget);
    });
  });
}
