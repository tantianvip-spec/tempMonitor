import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

/// A fake repository that returns controlled streams/lists instead of
/// hitting a real database. Uses [Stream.empty] so the subscription
/// closes immediately and the test doesn't hang.
class _FakeRepository extends SensorRepository {
  _FakeRepository(super.db);

  @override
  Stream<List<Device>> watchAllDevices() => Stream<List<Device>>.empty();

  @override
  Future<Reading?> getLatestReading(String deviceId) async => null;

  @override
  Future<List<Reading>> getReadingsForDevice(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) async =>
      [];
}

void main() {
  group('DashboardPage', () {
    testWidgets('shows empty state when no devices', (tester) async {
      final repo = _FakeRepository(null!);
      final cubit = DashboardCubit(repo);

      // Emit empty devices state so the UI renders the empty state
      // before the cubit's _devicesSubscription fires.
      cubit.emit(const DashboardState(devices: []));

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<DashboardCubit>.value(
          value: cubit,
          child: const DashboardPage(),
        ),
      ));
      await tester.pump();

      expect(find.text('请添加设备'), findsOneWidget);

      await cubit.close();
    });
  });
}
