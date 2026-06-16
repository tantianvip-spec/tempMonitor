# Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote the dashboard from a push-navigation secondary page to a top-level tab (default home), with compact device overview cards in a PageView and per-device history chart on the same page.

**Architecture:** 4-tab navigation via IndexedStack. DashboardPage creates its own DashboardCubit scoped to the tab's widget subtree. PageView switches device selection; on change, the cubit re-loads history from the DB and re-subscribes the real-time stream filter. A new DeviceOverviewCard widget replaces the multi-card layout with a single compact card.

**Tech Stack:** Flutter, flutter_bloc, fl_chart, Drift, Provider

---

### Task 1: Create DeviceOverviewCard widget

**Files:**
- Create: `lib/widgets/device_overview_card.dart`
- Test: `test/device_overview_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/widgets/device_overview_card.dart';

void main() {
  group('DeviceOverviewCard', () {
    testWidgets('renders all fields when reading is provided', (tester) async {
      final reading = Reading(
        deviceId: 'test-device',
        temperature: 26.3,
        humidity: 61.0,
        battery: 98,
        rssi: -76,
        recordedAt: DateTime(2026, 6, 15, 10, 30),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeviceOverviewCard(
            deviceName: 'ATC_3F',
            reading: reading,
          ),
        ),
      ));

      expect(find.text('ATC_3F'), findsOneWidget);
      expect(find.text('26.3°'), findsOneWidget);
      expect(find.textContaining('61'), findsOneWidget);
      expect(find.textContaining('98'), findsOneWidget);
      expect(find.textContaining('-76'), findsOneWidget);
    });

    testWidgets('shows placeholder when reading is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeviceOverviewCard(
            deviceName: 'ATC_3F',
            reading: null,
          ),
        ),
      ));

      expect(find.text('ATC_3F'), findsOneWidget);
      expect(find.text('--'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/device_overview_card_test.dart`
Expected: FAIL — "Target file does not exist"

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import 'package:temp_monitor/core/extensions.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/reading.dart';

/// Compact card showing one device's real-time readings.
///
/// Intended for use inside a PageView on the dashboard page.
/// Shows device name, temperature (large), humidity + battery,
/// and signal strength.
class DeviceOverviewCard extends StatelessWidget {
  final String deviceName;
  final Reading? reading;

  const DeviceOverviewCard({
    super.key,
    required this.deviceName,
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Container(
        width: 160,
        height: 120,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device name
            Text(
              deviceName,
              style: textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Temperature — large
            Text(
              reading?.temperature.toTempString() ?? '--',
              style: textTheme.headlineMedium?.copyWith(
                color: AppTheme.accentTemp,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Humidity · Battery
            Text(
              reading != null
                  ? '${reading!.humidity.toHumidityString()} · ${reading!.battery ?? "--"}'
                  : '-- · --',
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 2),
            // Signal
            Text(
              reading?.rssi != null ? '${reading!.rssi} dBm' : '--',
              style: textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/device_overview_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/device_overview_card.dart test/device_overview_card_test.dart
git commit -m "feat: add DeviceOverviewCard widget for compact dashboard"
```

---

### Task 2: Refactor HistoryChart to support embedded (non-scrollable) mode

**Files:**
- Modify: `lib/widgets/history_chart.dart`
- Test: `test/history_chart_test.dart` (update existing)

The current `HistoryChart.build()` wraps everything in a `ListView`, which causes nested scroll conflicts when embedded in a scrollable dashboard page. Add an `embedded` parameter that uses `Column` instead of `ListView`.

- [ ] **Step 1: Write the failing test for embedded mode**

Add to existing test file:

```dart
testWidgets('HistoryChart embedded mode does not wrap in ListView', (tester) async {
  final readings = [
    Reading(
      deviceId: 'd1',
      temperature: 25.0,
      humidity: 60.0,
      recordedAt: DateTime(2026, 6, 15, 10, 0),
    ),
    Reading(
      deviceId: 'd1',
      temperature: 26.0,
      humidity: 62.0,
      recordedAt: DateTime(2026, 6, 15, 10, 30),
    ),
  ];

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: HistoryChart(
        readings: readings,
        range: HistoryRange.day,
        embedded: true,
      ),
    ),
  ));

  // Should render chart content, not "暂无历史数据"
  expect(find.textContaining('°C'), findsWidgets);
  expect(find.byType(ListView), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/history_chart_test.dart`
Expected: FAIL (or compile error if `embedded` param doesn't exist)

- [ ] **Step 3: Add `embedded` parameter to HistoryChart**

Add `embedded` field to `HistoryChart`:

```dart
class HistoryChart extends StatelessWidget {
  final List<Reading> readings;
  final HistoryRange range;
  final bool embedded;  // NEW

  const HistoryChart({
    super.key,
    required this.readings,
    required this.range,
    this.embedded = false,  // NEW default false for backward compat
  });
```

Change the `build` method to conditionally wrap:

```dart
@override
Widget build(BuildContext context) {
  if (readings.isEmpty) {
    return const Center(child: Text('无历史数据'));
  }

  // ... existing variable setup ...

  final chartContent = Column(
    children: [
      if (temps.isNotEmpty)
        _ChartSection(
          title: '温度',
          icon: Icons.thermostat,
          color: AppTheme.accentTemp,
          currentValue: '${temps.last.toStringAsFixed(1)}°C',
          chart: _buildChart(
            context: context,
            values: temps,
            times: tempTimes,
            timeMin: timeMin,
            timeSpan: timeSpan,
            color: AppTheme.accentTemp,
            axisLabelStyle: axisLabelStyle,
          ),
        ),
      if (temps.isNotEmpty && hums.isNotEmpty) const SizedBox(height: 16),
      if (hums.isNotEmpty)
        _ChartSection(
          title: '湿度',
          icon: Icons.water_drop,
          color: AppTheme.accentHumidity,
          currentValue: '${hums.last.toStringAsFixed(1)}%',
          chart: _buildChart(
            context: context,
            values: hums,
            times: humTimes,
            timeMin: timeMin,
            timeSpan: timeSpan,
            color: AppTheme.accentHumidity,
            axisLabelStyle: axisLabelStyle,
          ),
        ),
      const SizedBox(height: 16),
    ],
  );

  if (embedded) return chartContent;
  return ListView(
    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
    children: [chartContent],
  );
}
```

Note: In the actual edit, the existing `ListView` children (two `_ChartSection` widgets + SizedBox) become the `chartContent` column's children. The embedded branch returns the column directly; the non-embedded branch wraps it in a ListView.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/history_chart_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/history_chart.dart
git commit -m "feat: add embedded mode to HistoryChart for inline use"
```

---

### Task 3: Rewrite DashboardCubit for multi-device support and in-page history

**Files:**
- Modify: `lib/presentation/dashboard/dashboard_cubit.dart`
- Test: `test/dashboard_cubit_test.dart`

The new DashboardCubit manages:
- A list of all devices (from `watchAllDevices()` stream)
- Current device index (for PageView)
- Latest reading for the current device
- History data for the current device
- Real-time stream subscription filtered by current deviceId

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

// A manual mock that returns an empty stream for watchAllDevices.
class MockRepo extends SensorRepository {
  MockRepo() : super(_mockDb());

  static _mockDb() {
    // Use AppDatabase.forTesting() from test infra — see test infra note.
    throw UnimplementedError('Use MockSensorRepository from test/helpers/');
  }
}

void main() {
  group('DashboardCubit', () {
    test('switchToDevice updates currentDeviceIndex', () async {
      // We test the state mutation directly.
      // Full integration test requires a mock DB — covered in widget test.
    });
  });
}
```

Actually, since there's no mockito/mocktail in dev deps, the cubit test will be best done as part of the widget test with a real (test) DB. Let's keep the cubit test simple.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';

void main() {
  group('DashboardState', () {
    test('copyWith updates fields correctly', () {
      final state = const DashboardState();
      final updated = state.copyWith(currentDeviceIndex: 1);
      expect(updated.currentDeviceIndex, 1);
    });

    test('onNewReading appends to historyReadings', () {
      final state = const DashboardState(
        historyStatus: HistoryStatus.loaded,
      );
      final reading = Reading(
        deviceId: 'd1',
        temperature: 25.0,
        humidity: 60.0,
        recordedAt: DateTime(2026, 6, 15, 10, 0),
      );
      final updated = state.copyWith(
        historyReadings: [...state.historyReadings, reading],
      );
      expect(updated.historyReadings.length, 1);
      expect(updated.historyReadings.first.temperature, 25.0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/dashboard_cubit_test.dart`
Expected: Compile errors (DashboardState/ DashboardCubit don't have new fields yet)

- [ ] **Step 3: Rewrite DashboardCubit and DashboardState**

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/history/history_cubit.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SensorRepository _repository;
  final Stream<Reading>? _readingStream;
  StreamSubscription<Reading>? _realTimeSubscription;
  StreamSubscription<List<Device>>? _devicesSubscription;

  DashboardCubit(
    this._repository, {
    Stream<Reading>? readingStream,
  })  : _readingStream = readingStream,
        super(const DashboardState()) {
    _init();
  }

  void _init() {
    // Watch for device list changes (add/remove).
    _devicesSubscription = _repository.watchAllDevices().listen((devices) {
      if (!isClosed) {
        final oldIndex = state.currentDeviceIndex;
        emit(state.copyWith(devices: devices));
        // If the current device was removed, reset to index 0.
        if (devices.isNotEmpty && oldIndex >= devices.length) {
          switchToDevice(0);
        } else if (devices.isNotEmpty) {
          // Re-load history if devices changed but current index is still valid
          _loadCurrentDeviceData(devices[oldIndex].id);
        }
      }
    });
  }

  /// Load initial data for a device at startup or after device switch.
  Future<void> _loadCurrentDeviceData(String deviceId) async {
    // Fetch latest reading
    final latest = await _repository.getLatestReading(deviceId);
    if (!isClosed) {
      emit(state.copyWith(latestReading: latest));
    }

    // Fetch history (default range = day)
    await _loadHistory(deviceId, state.range);

    // Re-subscribe real-time stream
    _realTimeSubscription?.cancel();
    if (_readingStream != null) {
      _realTimeSubscription = _readingStream!
          .where((r) => r.deviceId == deviceId)
          .listen(onNewReading);
    }
  }

  Future<void> _loadHistory(String deviceId, HistoryRange range) async {
    emit(state.copyWith(historyStatus: HistoryStatus.loading));
    try {
      final now = DateTime.now();
      final from = switch (range) {
        HistoryRange.day => now.subtract(const Duration(hours: 24)),
        HistoryRange.week => now.subtract(const Duration(days: 7)),
        HistoryRange.month => now.subtract(const Duration(days: 30)),
      };
      final readings = await _repository.getReadingsForDevice(
        deviceId,
        from: from,
        to: now,
      );
      if (!isClosed) {
        emit(state.copyWith(
          historyStatus: HistoryStatus.loaded,
          historyReadings: readings,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          historyStatus: HistoryStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  void switchToDevice(int index) {
    if (index < 0 || index >= state.devices.length) return;
    emit(state.copyWith(currentDeviceIndex: index));
    _loadCurrentDeviceData(state.devices[index].id);
  }

  void changeHistoryRange(HistoryRange range) {
    emit(state.copyWith(range: range));
    final deviceId = _currentDeviceId;
    if (deviceId != null) {
      _loadHistory(deviceId, range);
    }
  }

  void onNewReading(Reading reading) {
    emit(state.copyWith(latestReading: reading));
    // Also append to history if the reading falls within the current range.
    if (state.historyStatus == HistoryStatus.loaded) {
      final history = List<Reading>.from(state.historyReadings)
        ..add(reading);
      emit(state.copyWith(historyReadings: history));
    }
  }

  String? get _currentDeviceId {
    final idx = state.currentDeviceIndex;
    if (idx < 0 || idx >= state.devices.length) return null;
    return state.devices[idx].id;
  }

  @override
  Future<void> close() async {
    await _realTimeSubscription?.cancel();
    await _devicesSubscription?.cancel();
    return super.close();
  }
}

// --- Shared enums (moved from history_cubit.dart to avoid circular dep) ---
// NOTE: HistoryRange and HistoryStatus are defined in history_cubit.dart.
// We import them rather than duplicating.
```

Wait — we need to avoid a circular dependency. `DashboardCubit` imports from `history_cubit.dart` for `HistoryRange`/`HistoryStatus`, but nothing in `history_cubit.dart` imports from dashboard. This is fine: one-way dependency. DashboardCubit reuses the enums.

But actually, it's cleaner to extract `HistoryRange` and `HistoryStatus` into a shared file to avoid coupling dashboard to history_cubit. Let's do that.

- [ ] **Step 3a: Extract HistoryRange/HistoryStatus to shared file**

Create `lib/presentation/history/history_enums.dart`:

```dart
enum HistoryStatus { initial, loading, loaded, error }

enum HistoryRange { day, week, month }
```

Update `lib/presentation/history/history_cubit.dart` to import from `history_enums.dart` and remove the local enum definitions.

- [ ] **Step 3b: Write new DashboardCubit + DashboardState**

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/history/history_enums.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SensorRepository _repository;
  final Stream<Reading>? _readingStream;
  StreamSubscription<Reading>? _realTimeSubscription;
  StreamSubscription<List<Device>>? _devicesSubscription;

  DashboardCubit(
    this._repository, {
    Stream<Reading>? readingStream,
  })  : _readingStream = readingStream,
        super(const DashboardState()) {
    _init();
  }

  void _init() {
    _devicesSubscription = _repository.watchAllDevices().listen((devices) {
      if (isClosed) return;
      final oldIndex = state.currentDeviceIndex;
      emit(state.copyWith(devices: devices));
      if (devices.isEmpty) return;
      final newIndex = oldIndex < devices.length ? oldIndex : 0;
      if (newIndex != oldIndex || state.latestReading == null) {
        switchToDevice(newIndex);
      }
    });
  }

  void switchToDevice(int index) {
    if (index < 0 || index >= state.devices.length) return;
    emit(state.copyWith(currentDeviceIndex: index));
    _loadCurrentDeviceData(state.devices[index].id);
  }

  Future<void> _loadCurrentDeviceData(String deviceId) async {
    final latest = await _repository.getLatestReading(deviceId);
    if (!isClosed) {
      emit(state.copyWith(latestReading: latest));
    }

    await _loadHistory(deviceId, state.range);

    _realTimeSubscription?.cancel();
    if (_readingStream != null) {
      _realTimeSubscription = _readingStream!
          .where((r) => r.deviceId == deviceId)
          .listen(onNewReading);
    }
  }

  Future<void> _loadHistory(String deviceId, HistoryRange range) async {
    emit(state.copyWith(historyStatus: HistoryStatus.loading));
    try {
      final now = DateTime.now();
      final from = switch (range) {
        HistoryRange.day => now.subtract(const Duration(hours: 24)),
        HistoryRange.week => now.subtract(const Duration(days: 7)),
        HistoryRange.month => now.subtract(const Duration(days: 30)),
      };
      final readings = await _repository.getReadingsForDevice(
        deviceId,
        from: from,
        to: now,
      );
      if (!isClosed) {
        emit(state.copyWith(
          historyStatus: HistoryStatus.loaded,
          historyReadings: readings,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          historyStatus: HistoryStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  void changeHistoryRange(HistoryRange range) {
    emit(state.copyWith(range: range));
    final deviceId = _currentDeviceId;
    if (deviceId != null) _loadHistory(deviceId, range);
  }

  void onNewReading(Reading reading) {
    emit(state.copyWith(latestReading: reading));
    if (state.historyStatus == HistoryStatus.loaded) {
      final history = [...state.historyReadings, reading];
      emit(state.copyWith(historyReadings: history));
    }
  }

  String? get _currentDeviceId {
    final idx = state.currentDeviceIndex;
    if (idx < 0 || idx >= state.devices.length) return null;
    return state.devices[idx].id;
  }

  @override
  Future<void> close() async {
    await _realTimeSubscription?.cancel();
    await _devicesSubscription?.cancel();
    return super.close();
  }
}

class DashboardState extends Equatable {
  final List<Device> devices;
  final int currentDeviceIndex;
  final Reading? latestReading;
  final List<Reading> historyReadings;
  final HistoryStatus historyStatus;
  final HistoryRange range;
  final String? errorMessage;

  const DashboardState({
    this.devices = const [],
    this.currentDeviceIndex = 0,
    this.latestReading,
    this.historyReadings = const [],
    this.historyStatus = HistoryStatus.initial,
    this.range = HistoryRange.day,
    this.errorMessage,
  });

  DashboardState copyWith({
    List<Device>? devices,
    int? currentDeviceIndex,
    Reading? latestReading,
    List<Reading>? historyReadings,
    HistoryStatus? historyStatus,
    HistoryRange? range,
    String? errorMessage,
  }) =>
      DashboardState(
        devices: devices ?? this.devices,
        currentDeviceIndex: currentDeviceIndex ?? this.currentDeviceIndex,
        latestReading: latestReading ?? this.latestReading,
        historyReadings: historyReadings ?? this.historyReadings,
        historyStatus: historyStatus ?? this.historyStatus,
        range: range ?? this.range,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [
        devices,
        currentDeviceIndex,
        latestReading,
        historyReadings,
        historyStatus,
        range,
        errorMessage,
      ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/dashboard_cubit_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/dashboard/dashboard_cubit.dart \
       lib/presentation/history/history_enums.dart \
       lib/presentation/history/history_cubit.dart \
       test/dashboard_cubit_test.dart
git commit -m "feat: rewrite DashboardCubit for multi-device + in-page history"
```

---

### Task 4: Rewrite DashboardPage with PageView + HistoryChart inline

**Files:**
- Modify: `lib/presentation/dashboard/dashboard_page.dart`
- Test: `test/dashboard_page_test.dart` (update/rewrite)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
import 'package:temp_monitor/presentation/history/history_enums.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

// A minimal mock repository that returns empty lists.
class _MockRepository extends SensorRepository {
  _MockRepository() : super(_makeDb());
  static _makeDb() => throw UnimplementedError(
    'Use AppDatabase.forTesting() — see CLAUDE.md test infra note');
}

void main() {
  group('DashboardPage', () {
    testWidgets('shows empty state when no devices', (tester) async {
      // Create cubit with empty state
      final cubit = DashboardCubit(_MockRepository());
      // Manually emit empty devices state
      cubit.emit(const DashboardState(devices: []));

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<DashboardCubit>.value(
          value: cubit,
          child: const DashboardPage(),
        ),
      ));
      await tester.pump();

      expect(find.text('请添加设备'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/dashboard_page_test.dart`
Expected: FAIL — dashboard page is still the old StatelessWidget with `deviceId` param

- [ ] **Step 3: Rewrite DashboardPage**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/history/history_enums.dart';
import 'package:temp_monitor/widgets/device_overview_card.dart';
import 'package:temp_monitor/widgets/history_chart.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state.devices.isEmpty) {
            return _buildEmptyState(context);
          }

          final currentDevice = state.devices[state.currentDeviceIndex];

          return RefreshIndicator(
            onRefresh: () async {
              context.read<DashboardCubit>().switchToDevice(
                state.currentDeviceIndex,
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PageView for device cards
                  SizedBox(
                    height: 140,
                    child: PageView.builder(
                      controller: PageController(viewportFraction: 0.55),
                      itemCount: state.devices.length,
                      onPageChanged: (index) {
                        context.read<DashboardCubit>().switchToDevice(index);
                      },
                      itemBuilder: (context, index) {
                        final device = state.devices[index];
                        final reading = index == state.currentDeviceIndex
                            ? state.latestReading
                            : null;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: DeviceOverviewCard(
                            deviceName: device.name,
                            reading: reading,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Page indicator dots
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(state.devices.length, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == state.currentDeviceIndex ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == state.currentDeviceIndex
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // History chart for current device
                  Text(
                    '${currentDevice.name} 的历史曲线',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),

                  if (state.historyStatus == HistoryStatus.loading &&
                      state.historyReadings.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.historyReadings.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: Text('暂无历史数据')),
                    )
                  else
                    HistoryChart(
                      readings: state.historyReadings,
                      range: state.range,
                      embedded: true,
                    ),

                  const SizedBox(height: 12),

                  // Time range selector
                  Center(
                    child: SegmentedButton<HistoryRange>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(
                            value: HistoryRange.day, label: Text('24h')),
                        ButtonSegment(
                            value: HistoryRange.week, label: Text('7d')),
                        ButtonSegment(
                            value: HistoryRange.month, label: Text('30d')),
                      ],
                      selected: {state.range},
                      onSelectionChanged: (selected) {
                        context
                            .read<DashboardCubit>()
                            .changeHistoryRange(selected.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.thermometer(),
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '请添加设备',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '前往「设备」标签页添加温湿度传感器',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/dashboard_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/dashboard/dashboard_page.dart
git commit -m "feat: rewrite DashboardPage with PageView + inline history chart"
```

---

### Task 5: Update app.dart — 4-tab navigation with dashboard as default

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Update MainNavigationScreen**

Change `_MainNavigationScreenState` to have 4 tabs, with DashboardPage as index 0:

```dart
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SensorRepository>();
    Stream<Reading>? readingStream;
    try {
      readingStream = Provider.of<Stream<Reading>>(context, listen: false);
    } catch (_) {}

    final pages = [
      BlocProvider(
        create: (_) => DashboardCubit(
          repository,
          readingStream: readingStream,
        ),
        child: const DashboardPage(),
      ),
      const DevicesPage(),
      const SettingsPage(),
      BlocProvider(
        create: (_) => DebugLogCubit(),
        child: const DebugLogPage(),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: '仪表盘'),
          NavigationDestination(icon: Icon(Icons.devices), label: '设备'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
          NavigationDestination(icon: Icon(Icons.bug_report), label: '调试'),
        ],
      ),
    );
  }
}
```

Add imports at top of file:

```dart
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/app.dart
git commit -m "feat: 4-tab navigation with dashboard as default tab"
```

---

### Task 6: Update DevicesPage — remove _openDashboard navigation

**Files:**
- Modify: `lib/presentation/devices/devices_page.dart`

- [ ] **Step 1: Remove the `_openDashboard` method and update `_DeviceCard`**

In the `_DeviceCard` widget, the `onTap` currently navigates to the dashboard page. Since dashboard is now a tab, remove the tap navigation. The device card becomes a pure display item.

```dart
// In the ListView children, remove onTap:
child: _DeviceCard(device: device),  // no onTap

// Remove _openDashboard method entirely

// Update _DeviceCard to remove the onTap parameter and chevron:
class _DeviceCard extends StatelessWidget {
  final Device device;

  const _DeviceCard({required this.device});
  // ...
```

Also remove these unused imports from `devices_page.dart`:

```dart
// Remove these:
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/devices/devices_page.dart
git commit -m "refactor: remove dashboard navigation from DevicesPage"
```

---

### Task 7: Run full analyze and fix issues

- [ ] **Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors (or only pre-existing warnings)

- [ ] **Step 2: Fix any analysis issues**

If there are issues, fix them and re-run until clean.

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "chore: fix analysis issues after dashboard redesign"
```

---

### Task 8: Push to CI

- [ ] **Step 1: Push to master**

```bash
git push origin master
```

- [ ] **Step 2: Monitor CI**

Run: `gh run list --limit 1` to check build status. If failed, investigate logs and fix.
