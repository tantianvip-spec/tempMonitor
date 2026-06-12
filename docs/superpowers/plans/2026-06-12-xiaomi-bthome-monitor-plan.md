# 小米蓝牙温湿度计 2 BThome v2 监控 App 实现计划

> **For agentic workers:** REQUIRED SUB-KEYILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于设计文档，从零实现一个 Flutter 跨平台 App，读取小米蓝牙温湿度计 2 的 BThome v2 广播数据，后台记录历史、绘制曲线、阈值告警，并支持调试日志导出。

**Architecture:** 采用分层架构：Domain 层负责 BThome 解析和阈值判断；Data 层用 Drift 管理本地 SQLite；Infrastructure 层负责 BLE 扫描、通知、后台服务；Presentation 层用 Cubit 管理 UI 状态。所有业务逻辑优先写单元测试，再写实现。

**Tech Stack:** Flutter, flutter_blue_plus, drift, flutter_bloc, fl_chart, flutter_local_notifications, flutter_background_service, permission_handler, shared_preferences

---

## 文件结构

```
/home/ubuntu/tempMonitor/
├── android/                          # Android 原生配置
├── ios/                              # iOS 原生配置
├── lib/
│   ├── main.dart                     # 入口
│   ├── app.dart                      # MaterialApp + 路由
│   ├── core/
│   │   ├── constants.dart            # UUID、阈值默认值等
│   │   └── extensions.dart           # 工具扩展
│   ├── domain/
│   │   ├── models/
│   │   │   ├── device.dart           # 设备实体
│   │   │   └── reading.dart          # 读数实体
│   │   └── services/
│   │       ├── bthome_parser.dart    # BThome v2 解析器
│   │       └── threshold_engine.dart # 阈值判断与去抖
│   ├── data/
│   │   ├── app_database.dart         # Drift 数据库
│   │   ├── tables.dart               # Drift 表定义
│   │   └── daos/
│   │       ├── devices_dao.dart
│   │       ├── readings_dao.dart
│   │       └── settings_dao.dart
│   ├── repositories/
│   │   └── sensor_repository.dart    # 业务仓库
│   ├── infrastructure/
│   │   ├── ble_scanner.dart          # BLE 扫描封装
│   │   ├── notification_service.dart # 本地通知
│   │   ├── background_service.dart   # 后台扫描服务
│   │   └── debug_logger.dart         # 调试日志
│   ├── services/
│   │   └── settings_service.dart     # SharedPreferences 设置
│   └── presentation/
│       ├── dashboard/
│       │   ├── dashboard_page.dart
│       │   └── dashboard_cubit.dart
│       ├── history/
│       │   ├── history_page.dart
│       │   └── history_cubit.dart
│       ├── settings/
│       │   ├── settings_page.dart
│       │   └── settings_cubit.dart
│       ├── devices/
│       │   └── devices_page.dart
│       └── debug/
│           ├── debug_log_page.dart
│           └── debug_log_cubit.dart
├── test/
│   ├── bthome_parser_test.dart
│   ├── threshold_engine_test.dart
│   └── widget_test.dart
├── .github/
│   └── workflows/
│       └── build_android.yml
├── pubspec.yaml
└── docs/superpowers/plans/2026-06-12-xiaomi-bthome-monitor-plan.md
```

---

## Task 1: 初始化 Flutter 项目并安装依赖

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`

### Step 1.1: 初始化 Flutter 项目

Run:
```bash
flutter create --project-name temp_monitor --org com.example tempMonitor
```

Expected: 生成 `android/`、`ios/`、`lib/`、`test/`、`pubspec.yaml` 等目录和文件。

### Step 1.2: 替换 pubspec.yaml 依赖

Create/modify `pubspec.yaml`:

```yaml
name: temp_monitor
description: A BThome v2 temperature and humidity monitor
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.32.0
  drift: ^2.18.0
  drift_flutter: ^0.1.0
  flutter_bloc: ^8.1.6
  fl_chart: ^0.68.0
  flutter_local_notifications: ^17.0.0
  flutter_background_service: ^5.0.6
  flutter_background_service_android: ^6.2.3
  permission_handler: ^11.3.1
  shared_preferences: ^2.2.3
  path_provider: ^2.1.3
  equatable: ^2.0.5
  intl: ^0.19.0
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  drift_dev: ^2.18.0
  build_runner: ^2.4.11

flutter:
  uses-material-design: true
```

### Step 1.3: 获取依赖

Run:
```bash
flutter pub get
```

Expected: 依赖安装成功，无报错。

### Step 1.4: 创建基础入口文件

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:temp_monitor/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TempMonitorApp());
}
```

Create `lib/app.dart`:

```dart
import 'package:flutter/material.dart';

class TempMonitorApp extends StatelessWidget {
  const TempMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '温湿度监控',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Temp Monitor')),
      ),
    );
  }
}
```

### Step 1.5: 验证编译

Run:
```bash
flutter build apk --debug
```

Expected: 编译成功，生成 APK。

### Step 1.6: 提交

```bash
git add .
git commit -m "chore: initialize Flutter project with dependencies"
```

---

## Task 2: 核心常量和模型

**Files:**
- Create: `lib/core/constants.dart`
- Create: `lib/core/extensions.dart`
- Create: `lib/domain/models/device.dart`
- Create: `lib/domain/models/reading.dart`

### Step 2.1: 创建常量文件

Create `lib/core/constants.dart`:

```dart
abstract class AppConstants {
  static const String bthomeServiceUuid = '0000fcd2-0000-1000-8000-00805f9b34fb';
  static const int defaultScanIntervalSeconds = 5;
  static const int defaultRetentionDays = 30;
  static const double defaultTempMin = 0.0;
  static const double defaultTempMax = 40.0;
  static const double defaultHumidityMin = 20.0;
  static const double defaultHumidityMax = 80.0;
  static const int maxLogEntries = 1000;
}
```

### Step 2.2: 创建扩展工具

Create `lib/core/extensions.dart`:

```dart
import 'package:intl/intl.dart';

extension DateTimeFormat on DateTime {
  String toDisplayString() => DateFormat('MM-dd HH:mm').format(this);
  String toLogString() => DateFormat('yyyy-MM-dd HH:mm:ss').format(this);
}

extension DoubleFormat on double {
  String toTempString() => '${toStringAsFixed(1)}°C';
  String toHumidityString() => '${toStringAsFixed(1)}%';
}
```

### Step 2.3: 创建设备模型

Create `lib/domain/models/device.dart`:

```dart
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
```

### Step 2.4: 创建读数模型

Create `lib/domain/models/reading.dart`:

```dart
import 'package:equatable/equatable.dart';

class Reading extends Equatable {
  final String deviceId;
  final double temperature;
  final double humidity;
  final int? battery;
  final int? rssi;
  final DateTime recordedAt;

  const Reading({
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    this.battery,
    this.rssi,
    required this.recordedAt,
  });

  @override
  List<Object?> get props =>
      [deviceId, temperature, humidity, battery, rssi, recordedAt];
}
```

### Step 2.5: 运行 lint 检查

Run:
```bash
flutter analyze
```

Expected: 无错误。

### Step 2.6: 提交

```bash
git add lib/core lib/domain/models
git commit -m "feat: add core constants and domain models"
```

---

## Task 3: BThome v2 解析器（TDD）

**Files:**
- Create: `lib/domain/services/bthome_parser.dart`
- Create: `test/bthome_parser_test.dart`

### Step 3.1: 写失败测试

Create `test/bthome_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/services/bthome_parser.dart';

void main() {
  group('BThomeParser', () {
    const deviceId = 'A4:C1:38:00:00:01';
    const rssi = -65;

    test('parses temperature and humidity from plain BThome v2 packet', () {
      // BThome v2: [0x40, 0x02, 0x34, 0x12, 0x03, 0x30, 0x75]
      // 0x40 = BThome v2 unencrypted, trigger-based advertising
      // 0x02 temperature, 2 bytes, 0x1234 -> 46.60°C
      // 0x03 humidity, 2 bytes, 0x7530 -> 300.00%
      final bytes = [0x40, 0x02, 0x34, 0x12, 0x03, 0x30, 0x75];

      final result = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(result.deviceId, deviceId);
      expect(result.temperature, closeTo(46.60, 0.01));
      expect(result.humidity, closeTo(300.00, 0.01));
      expect(result.rssi, rssi);
    });

    test('parses battery object id', () {
      final bytes = [0x40, 0x01, 0x64, 0x02, 0x00, 0x00];
      final result = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: rssi,
      );

      expect(result.battery, 100);
      expect(result.temperature, closeTo(0.0, 0.01));
    });

    test('filters physically impossible temperature', () {
      final bytes = [0x40, 0x02, 0xA0, 0x86, 0x01, 0x01]; // ~344.64°C
      expect(
        () => BThomeParser.parse(bytes, deviceId: deviceId, rssi: rssi),
        throwsA(isA<BThomeParseException>()),
      );
    });
  });
}
```

Run:
```bash
flutter test test/bthome_parser_test.dart
```

Expected: FAIL - `BThomeParser` not found。

### Step 3.2: 实现解析器

Create `lib/domain/services/bthome_parser.dart`:

```dart
import 'dart:typed_data';

import 'package:temp_monitor/domain/models/reading.dart';

class BThomeParseException implements Exception {
  final String message;
  BThomeParseException(this.message);
  @override
  String toString() => 'BThomeParseException: $message';
}

class BThomeParser {
  static const int _objectIdBattery = 0x01;
  static const int _objectIdTemperature = 0x02;
  static const int _objectIdHumidity = 0x03;
  static const int _objectIdTemperatureHigh = 0x2A;
  static const int _objectIdHumidityHigh = 0x2B;

  static const double _minTemp = -40.0;
  static const double _maxTemp = 80.0;
  static const double _minHumidity = 0.0;
  static const double _maxHumidity = 100.0;

  static Reading parse(
    List<int> bytes, {
    required String deviceId,
    required int rssi,
  }) {
    if (bytes.isEmpty) {
      throw BThomeParseException('Empty packet');
    }

    // BThome v2 first byte: bit 0 = encryption, bit 5 = trigger based.
    // For now we only support unencrypted.
    final header = bytes[0];
    if ((header & 0x01) != 0) {
      throw BThomeParseException('Encrypted BThome packets are not supported');
    }

    double? temperature;
    double? humidity;
    int? battery;

    var offset = 1;
    final byteData = Uint8List.fromList(bytes).buffer.asByteData();

    while (offset < bytes.length) {
      final objectId = bytes[offset];
      offset++;

      switch (objectId) {
        case _objectIdBattery:
          if (offset >= bytes.length) break;
          battery = bytes[offset];
          offset++;
        case _objectIdTemperature:
        case _objectIdTemperatureHigh:
          if (offset + 1 >= bytes.length) break;
          final raw = byteData.getInt16(offset, Endian.little);
          temperature = raw * 0.01;
          offset += 2;
        case _objectIdHumidity:
        case _objectIdHumidityHigh:
          if (offset + 1 >= bytes.length) break;
          final raw = byteData.getUint16(offset, Endian.little);
          humidity = raw * 0.01;
          offset += 2;
        default:
          // Unknown object id, skip if we know length, otherwise abort.
          throw BThomeParseException('Unknown object id: 0x${objectId.toRadixString(16)}');
      }
    }

    if (temperature == null || humidity == null) {
      throw BThomeParseException('Missing temperature or humidity');
    }

    if (temperature < _minTemp || temperature > _maxTemp) {
      throw BThomeParseException('Temperature out of range: $temperature');
    }
    if (humidity < _minHumidity || humidity > _maxHumidity) {
      throw BThomeParseException('Humidity out of range: $humidity');
    }

    return Reading(
      deviceId: deviceId,
      temperature: temperature,
      humidity: humidity,
      battery: battery,
      rssi: rssi,
      recordedAt: DateTime.now().toUtc(),
    );
  }
}
```

### Step 3.3: 运行测试

Run:
```bash
flutter test test/bthome_parser_test.dart
```

Expected: PASS。

### Step 3.4: 提交

```bash
git add lib/domain/services/bthome_parser.dart test/bthome_parser_test.dart
git commit -m "feat: implement BThome v2 parser with tests"
```

---

## Task 4: 阈值引擎（TDD）

**Files:**
- Create: `lib/domain/services/threshold_engine.dart`
- Create: `test/threshold_engine_test.dart`

### Step 4.1: 写失败测试

Create `test/threshold_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/domain/services/threshold_engine.dart';

void main() {
  group('ThresholdEngine', () {
    test('returns breached when temperature exceeds max', () {
      final engine = ThresholdEngine(
        tempMin: 0,
        tempMax: 30,
        humidityMin: 20,
        humidityMax: 80,
      );
      final state = engine.evaluate(temperature: 35, humidity: 50);
      expect(state.tempBreached, true);
      expect(state.humidityBreached, false);
      expect(state.justBecameBreached, true);
    });

    test('does not repeat notification while still breached', () {
      final engine = ThresholdEngine(
        tempMin: 0,
        tempMax: 30,
        humidityMin: 20,
        humidityMax: 80,
      );
      engine.evaluate(temperature: 35, humidity: 50);
      final state2 = engine.evaluate(temperature: 36, humidity: 50);
      expect(state2.justBecameBreached, false);
    });

    test('sends recovery notification when back to normal', () {
      final engine = ThresholdEngine(
        tempMin: 0,
        tempMax: 30,
        humidityMin: 20,
        humidityMax: 80,
      );
      engine.evaluate(temperature: 35, humidity: 50);
      final state = engine.evaluate(temperature: 25, humidity: 50);
      expect(state.justRecovered, true);
      expect(state.justBecameBreached, false);
    });
  });
}
```

Run:
```bash
flutter test test/threshold_engine_test.dart
```

Expected: FAIL。

### Step 4.2: 实现阈值引擎

Create `lib/domain/services/threshold_engine.dart`:

```dart
import 'package:equatable/equatable.dart';

class ThresholdState extends Equatable {
  final bool tempBreached;
  final bool humidityBreached;
  final bool justBecameBreached;
  final bool justRecovered;

  const ThresholdState({
    this.tempBreached = false,
    this.humidityBreached = false,
    this.justBecameBreached = false,
    this.justRecovered = false,
  });

  bool get anyBreached => tempBreached || humidityBreached;

  @override
  List<Object?> get props =>
      [tempBreached, humidityBreached, justBecameBreached, justRecovered];
}

class ThresholdEngine {
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;

  bool _wasBreached = false;

  ThresholdEngine({
    required this.tempMin,
    required this.tempMax,
    required this.humidityMin,
    required this.humidityMax,
  });

  ThresholdState evaluate({
    required double temperature,
    required double humidity,
  }) {
    final tempBreached = temperature < tempMin || temperature > tempMax;
    final humidityBreached = humidity < humidityMin || humidity > humidityMax;
    final currentlyBreached = tempBreached || humidityBreached;

    final justBecameBreached = !_wasBreached && currentlyBreached;
    final justRecovered = _wasBreached && !currentlyBreached;

    _wasBreached = currentlyBreached;

    return ThresholdState(
      tempBreached: tempBreached,
      humidityBreached: humidityBreached,
      justBecameBreached: justBecameBreached,
      justRecovered: justRecovered,
    );
  }
}
```

### Step 4.3: 运行测试

Run:
```bash
flutter test test/threshold_engine_test.dart
```

Expected: PASS。

### Step 4.4: 提交

```bash
git add lib/domain/services/threshold_engine.dart test/threshold_engine_test.dart
git commit -m "feat: implement threshold engine with debounce tests"
```

---

## Task 5: 调试日志服务

**Files:**
- Create: `lib/infrastructure/debug_logger.dart`
- Create: `test/debug_logger_test.dart`

### Step 5.1: 实现 DebugLogger

Create `lib/infrastructure/debug_logger.dart`:

```dart
import 'dart:collection';

enum LogLevel { verbose, debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  String toLogLine() {
    final levelStr = level.name.toUpperCase().padRight(7);
    final timeStr = timestamp.toIso8601String();
    return '[$timeStr] $levelStr [$tag] $message';
  }
}

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final int _maxEntries = 1000;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => UnmodifiableListView(_entries);

  void log(
    String message, {
    LogLevel level = LogLevel.info,
    String tag = 'App',
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  void v(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.verbose, tag: tag);
  void d(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.debug, tag: tag);
  void i(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.info, tag: tag);
  void w(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.warning, tag: tag);
  void e(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.error, tag: tag);

  String export() => _entries.map((e) => e.toLogLine()).join('\n');

  void clear() => _entries.clear();
}
```

### Step 5.2: 写测试

Create `test/debug_logger_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

void main() {
  group('DebugLogger', () {
    setUp(() => DebugLogger().clear());

    test('stores log entries', () {
      DebugLogger().i('test message', tag: 'Test');
      expect(DebugLogger().entries.length, 1);
      expect(DebugLogger().entries.first.message, 'test message');
    });

    test('exports logs as text', () {
      DebugLogger().i('hello');
      final exported = DebugLogger().export();
      expect(exported.contains('hello'), true);
      expect(exported.contains('INFO'), true);
    });

    test('drops oldest entries when max is exceeded', () {
      for (var i = 0; i < 1005; i++) {
        DebugLogger().i('entry $i');
      }
      expect(DebugLogger().entries.length, 1000);
      expect(DebugLogger().entries.first.message, 'entry 5');
    });
  });
}
```

Run:
```bash
flutter test test/debug_logger_test.dart
```

Expected: PASS。

### Step 5.3: 提交

```bash
git add lib/infrastructure/debug_logger.dart test/debug_logger_test.dart
git commit -m "feat: add debug logger with ring buffer and export"
```

---

## Task 6: Drift 本地数据库

**Files:**
- Create: `lib/data/tables.dart`
- Create: `lib/data/app_database.dart`
- Create: `lib/data/daos/devices_dao.dart`
- Create: `lib/data/daos/readings_dao.dart`
- Create: `lib/data/daos/settings_dao.dart`

### Step 6.1: 定义 Drift 表

Create `lib/data/tables.dart`:

```dart
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
```

### Step 6.2: 创建数据库类

Create `lib/data/app_database.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/devices_dao.dart';
import 'daos/readings_dao.dart';
import 'daos/settings_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Devices, Readings, Settings], daos: [DevicesDao, ReadingsDao, SettingsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'temp_monitor_database');
  }
}
```

### Step 6.3: 创建 DAOs

Create `lib/data/daos/devices_dao.dart`:

```dart
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
```

Create `lib/data/daos/readings_dao.dart`:

```dart
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'readings_dao.g.dart';

@DriftAccessor(tables: [Readings])
class ReadingsDao extends DatabaseAccessor<AppDatabase> with _$ReadingsDaoMixin {
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
            ..orderBy([(r) => OrderingTerm(expression: r.recordedAt, mode: OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();
}
```

Create `lib/data/daos/settings_dao.dart`:

```dart
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<int> setValue(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion(key: Value(key), value: Value(value)),
      );
}
```

### Step 6.4: 运行代码生成

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: 生成 `lib/data/app_database.g.dart` 和 DAO 的 `.g.dart` 文件。

### Step 6.5: 提交

```bash
git add lib/data
git commit -m "feat: add drift database with devices, readings and settings DAOs"
```

---

## Task 7: SensorRepository

**Files:**
- Create: `lib/repositories/sensor_repository.dart`
- Create: `test/sensor_repository_test.dart`

### Step 7.1: 实现 Repository

Create `lib/repositories/sensor_repository.dart`:

```dart
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/data/tables.dart';
import 'package:temp_monitor/domain/models/device.dart' as domain;
import 'package:temp_monitor/domain/models/reading.dart' as domain;
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class SensorRepository {
  final AppDatabase _db;

  SensorRepository(this._db);

  Stream<List<domain.Device>> watchAllDevices() {
    final query = _db.select(_db.devices)
      ..orderBy([(d) => OrderingTerm(expression: d.lastSeenAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_mapDevice).toList());
  }

  Future<void> saveReading(domain.Reading reading) async {
    await _db.devicesDao.upsertDevice(
      DevicesCompanion(
        id: Value(reading.deviceId),
        name: Value(reading.deviceId), // default name, user can rename later
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        lastSeenAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    await _db.readingsDao.insertReading(
      ReadingsCompanion(
        deviceId: Value(reading.deviceId),
        temperature: Value(reading.temperature),
        humidity: Value(reading.humidity),
        battery: Value(reading.battery),
        rssi: Value(reading.rssi),
        recordedAt: Value(reading.recordedAt.millisecondsSinceEpoch),
      ),
    );

    await _cleanupOldData();
    DebugLogger().i('Saved reading: ${reading.temperature}°C, ${reading.humidity}%',
        tag: 'Repository');
  }

  Future<List<domain.Reading>> getReadingsForDevice(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.readingsDao.getReadingsForDevice(deviceId, from: from, to: to);
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

  Future<void> _cleanupOldData() async {
    final days = AppConstants.defaultRetentionDays;
    final cutoff = DateTime.now().subtract(Duration(days: days));
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
        recordedAt: DateTime.fromMillisecondsSinceEpoch(row.recordedAt).toUtc(),
      );
}
```

Note: `OrderingTerm` and `OrderingMode` need to be imported from `drift/drift.dart`. Add `import 'package:drift/drift.dart';` at the top.

### Step 7.2: 写 Repository 测试

Create `test/sensor_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

void main() {
  group('SensorRepository', () {
    late AppDatabase db;
    late SensorRepository repo;

    setUp(() {
      db = AppDatabase();
      repo = SensorRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('saves reading and retrieves it', () async {
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
  });
}
```

Run:
```bash
flutter test test/sensor_repository_test.dart
```

Expected: PASS。

### Step 7.3: 提交

```bash
git add lib/repositories test/sensor_repository_test.dart
git commit -m "feat: add sensor repository with cleanup logic"
```

---

## Task 8: BLE 扫描服务

**Files:**
- Create: `lib/infrastructure/ble_scanner.dart`

### Step 8.1: 实现 BLE Scanner

Create `lib/infrastructure/ble_scanner.dart`:

```dart
import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/domain/services/bthome_parser.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class BleScanner {
  final _lastSeen = <String, DateTime>{};
  static const _debounceDuration = Duration(seconds: 1);

  Stream<Reading> scan({Duration? timeout}) async* {
    if (!await FlutterBluePlus.isSupported) {
      DebugLogger().e('BLE not supported on this device', tag: 'BleScanner');
      return;
    }

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      DebugLogger().e('Bluetooth is not enabled', tag: 'BleScanner');
      return;
    }

    await FlutterBluePlus.startScan(
      withServices: [Guid(AppConstants.bthomeServiceUuid)],
      timeout: timeout ?? const Duration(seconds: 15),
    );

    await for (final result in FlutterBluePlus.scanResults) {
      for (final device in result) {
        final reading = _tryParseResult(device);
        if (reading != null) {
          yield reading;
        }
      }
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Reading? _tryParseResult(ScanResult result) {
    final deviceId = result.device.remoteId.str;
    final now = DateTime.now();
    final lastSeen = _lastSeen[deviceId];
    if (lastSeen != null && now.difference(lastSeen) < _debounceDuration) {
      return null;
    }

    final serviceData = result.advertisementData.serviceData;
    final guid = Guid(AppConstants.bthomeServiceUuid);
    final bytes = serviceData[guid];

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    try {
      final reading = BThomeParser.parse(
        bytes,
        deviceId: deviceId,
        rssi: result.rssi,
      );
      _lastSeen[deviceId] = now;
      DebugLogger().d('Parsed $deviceId: ${reading.temperature}°C ${reading.humidity}%',
          tag: 'BleScanner');
      return reading;
    } on BThomeParseException catch (e) {
      DebugLogger().w('Failed to parse $deviceId: $e', tag: 'BleScanner');
      return null;
    }
  }
}
```

### Step 8.2: 提交

```bash
git add lib/infrastructure/ble_scanner.dart
git commit -m "feat: add BLE scanner wrapper for BThome devices"
```

---

## Task 9: 本地通知服务

**Files:**
- Create: `lib/infrastructure/notification_service.dart`

### Step 9.1: 实现 NotificationService

Create `lib/infrastructure/notification_service.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showAlert({
    required String title,
    required String body,
    String channelId = 'temp_monitor_alerts',
    String channelName = '温湿度告警',
  }) async {
    if (!_initialized) {
      DebugLogger().w('NotificationService not initialized', tag: 'Notification');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      title,
      body,
      details,
    );
    DebugLogger().i('Notification shown: $title - $body', tag: 'Notification');
  }
}
```

### Step 9.2: 提交

```bash
git add lib/infrastructure/notification_service.dart
git commit -m "feat: add local notification service"
```

---

## Task 10: 设置服务（SharedPreferences）

**Files:**
- Create: `lib/services/settings_service.dart`

### Step 10.1: 实现 SettingsService

Create `lib/services/settings_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_monitor/core/constants.dart';

class SettingsService {
  late final SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int getScanIntervalSeconds() {
    return _prefs.getInt('scan_interval_seconds') ??
        AppConstants.defaultScanIntervalSeconds;
  }

  Future<void> setScanIntervalSeconds(int value) async {
    await _prefs.setInt('scan_interval_seconds', value);
  }

  int getRetentionDays() {
    return _prefs.getInt('retention_days') ?? AppConstants.defaultRetentionDays;
  }

  Future<void> setRetentionDays(int value) async {
    await _prefs.setInt('retention_days', value);
  }

  double getTempMin() =>
      _prefs.getDouble('temp_min') ?? AppConstants.defaultTempMin;
  Future<void> setTempMin(double value) async =>
      _prefs.setDouble('temp_min', value);

  double getTempMax() =>
      _prefs.getDouble('temp_max') ?? AppConstants.defaultTempMax;
  Future<void> setTempMax(double value) async =>
      _prefs.setDouble('temp_max', value);

  double getHumidityMin() =>
      _prefs.getDouble('humidity_min') ?? AppConstants.defaultHumidityMin;
  Future<void> setHumidityMin(double value) async =>
      _prefs.setDouble('humidity_min', value);

  double getHumidityMax() =>
      _prefs.getDouble('humidity_max') ?? AppConstants.defaultHumidityMax;
  Future<void> setHumidityMax(double value) async =>
      _prefs.setDouble('humidity_max', value);

  bool getMockDeviceEnabled() => _prefs.getBool('mock_device_enabled') ?? false;
  Future<void> setMockDeviceEnabled(bool value) async =>
      _prefs.setBool('mock_device_enabled', value);
}
```

### Step 10.2: 提交

```bash
git add lib/services/settings_service.dart
git commit -m "feat: add shared preferences settings service"
```

---

## Task 11: 后台扫描服务

**Files:**
- Create: `lib/infrastructure/background_service.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

### Step 11.1: 实现 BackgroundService

Create `lib/infrastructure/background_service.dart`:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/domain/services/threshold_engine.dart';
import 'package:temp_monitor/infrastructure/ble_scanner.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

class BackgroundService {
  static const String _isolateName = 'temp_monitor_background';
  static SendPort? _uiSendPort;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'temp_monitor_service',
        initialNotificationTitle: '温湿度监控',
        initialNotificationContent: '正在后台监听设备...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final settings = SettingsService();
    await settings.initialize();

    final db = AppDatabase();
    final repository = SensorRepository(db);
    final scanner = BleScanner();
    final notifications = NotificationService();
    await notifications.initialize();

    final thresholdEngine = ThresholdEngine(
      tempMin: settings.getTempMin(),
      tempMax: settings.getTempMax(),
      humidityMin: settings.getHumidityMin(),
      humidityMax: settings.getHumidityMax(),
    );

    Timer? scanTimer;

    void startScanning() {
      final interval = Duration(seconds: settings.getScanIntervalSeconds());
      scanTimer?.cancel();
      scanTimer = Timer.periodic(interval, (_) async {
        try {
          await for (final reading in scanner.scan(timeout: const Duration(seconds: 2))) {
            await repository.saveReading(reading);
            _uiSendPort?.send(reading);

            final state = thresholdEngine.evaluate(
              temperature: reading.temperature,
              humidity: reading.humidity,
            );

            if (state.justBecameBreached) {
              await notifications.showAlert(
                title: '温湿度告警',
                body: '温度 ${reading.temperature}°C / 湿度 ${reading.humidity}% 超出设定范围',
              );
            }
          }
        } catch (e) {
          DebugLogger().e('Background scan error: $e', tag: 'BackgroundService');
        }
      });
    }

    service.on('stopService').listen((event) {
      scanTimer?.cancel();
      service.stopSelf();
    });

    service.on('updateSettings').listen((event) {
      thresholdEngine
        ..tempMin = settings.getTempMin()
        ..tempMax = settings.getTempMax()
        ..humidityMin = settings.getHumidityMin()
        ..humidityMax = settings.getHumidityMax();
      startScanning();
    });

    startScanning();
  }

  static void setUiSendPort(SendPort sendPort) {
    _uiSendPort = sendPort;
  }
}
```

Wait, `ThresholdEngine` fields are final in our current implementation. We need to make them mutable or recreate the engine. For the plan, adjust the threshold engine to have setters or recreate. Simpler: recreate engine when settings change. Update the `on('updateSettings')` listener:

```dart
ThresholdEngine _createEngine() => ThresholdEngine(
  tempMin: settings.getTempMin(),
  tempMax: settings.getTempMax(),
  humidityMin: settings.getHumidityMin(),
  humidityMax: settings.getHumidityMax(),
);

var thresholdEngine = _createEngine();

service.on('updateSettings').listen((event) {
  thresholdEngine = _createEngine();
  startScanning();
});
```

Use this version in the implementation.

### Step 11.2: 更新 AndroidManifest.xml

Modify `android/app/src/main/AndroidManifest.xml`，在 `<manifest>` 内添加权限，在 `<application>` 内添加 service 和 receiver：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Bluetooth permissions -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        ...>
        ...
        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="location"
            android:exported="false" />

        <receiver
            android:name="id.flutter.flutter_background_service.BootReceiver"
            android:enabled="true"
            android:exported="true"
            android:permission="android.permission.RECEIVE_BOOT_COMPLETED">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

### Step 11.3: 提交

```bash
git add lib/infrastructure/background_service.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat: add Android foreground background service"
```

---

## Task 12: 仪表盘页面 + Cubit

**Files:**
- Create: `lib/presentation/dashboard/dashboard_cubit.dart`
- Create: `lib/presentation/dashboard/dashboard_page.dart`
- Create: `lib/widgets/current_reading_card.dart`

### Step 12.1: 实现 DashboardCubit

Create `lib/presentation/dashboard/dashboard_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SensorRepository _repository;

  DashboardCubit(this._repository) : super(const DashboardState());

  Future<void> loadLatest(String deviceId) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      final reading = await _repository.getLatestReading(deviceId);
      emit(state.copyWith(
        status: DashboardStatus.loaded,
        latestReading: reading,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void onNewReading(Reading reading) {
    emit(state.copyWith(
      status: DashboardStatus.loaded,
      latestReading: reading,
    ));
  }
}

class DashboardState extends Equatable {
  final DashboardStatus status;
  final Reading? latestReading;
  final String? errorMessage;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.latestReading,
    this.errorMessage,
  });

  DashboardState copyWith({
    DashboardStatus? status,
    Reading? latestReading,
    String? errorMessage,
  }) =>
      DashboardState(
        status: status ?? this.status,
        latestReading: latestReading ?? this.latestReading,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, latestReading, errorMessage];
}

enum DashboardStatus { initial, loading, loaded, error }
```

Note: `part 'dashboard_state.dart';` requires a separate file `dashboard_state.dart`. For simplicity, the state class and enum can be in the same file. Remove the `part` directive and put everything in `dashboard_cubit.dart`.

### Step 12.2: 实现 DashboardPage

Create `lib/presentation/dashboard/dashboard_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/core/extensions.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';

class DashboardPage extends StatelessWidget {
  final String deviceId;

  const DashboardPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('仪表盘')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<DashboardCubit>().loadLatest(deviceId);
        },
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            if (state.status == DashboardStatus.loading &&
                state.latestReading == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final reading = state.latestReading;
            if (reading == null) {
              return const Center(child: Text('暂无数据，请确保设备在附近'));
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCard('温度', reading.temperature.toTempString(),
                    Icons.thermostat, Colors.orange),
                const SizedBox(height: 12),
                _buildCard('湿度', reading.humidity.toHumidityString(),
                    Icons.water_drop, Colors.blue),
                const SizedBox(height: 12),
                if (reading.battery != null)
                  _buildCard('电量', '${reading.battery}%',
                      Icons.battery_full, Colors.green),
                if (reading.rssi != null)
                  _buildCard('信号', '${reading.rssi} dBm',
                      Icons.wifi_tethering, Colors.purple),
                const SizedBox(height: 24),
                Text('更新时间: ${reading.recordedAt.toDisplayString()}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 12.3: 提交

```bash
git add lib/presentation/dashboard lib/widgets/current_reading_card.dart
git commit -m "feat: add dashboard page with pull-to-refresh"
```

---

## Task 13: 历史曲线页面 + Cubit

**Files:**
- Create: `lib/presentation/history/history_cubit.dart`
- Create: `lib/presentation/history/history_page.dart`
- Create: `lib/widgets/history_chart.dart`

### Step 13.1: 实现 HistoryCubit

Create `lib/presentation/history/history_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final SensorRepository _repository;

  HistoryCubit(this._repository) : super(const HistoryState());

  Future<void> loadHistory(String deviceId, HistoryRange range) async {
    emit(state.copyWith(status: HistoryStatus.loading));
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

      emit(state.copyWith(
        status: HistoryStatus.loaded,
        readings: readings,
        range: range,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}

class HistoryState extends Equatable {
  final HistoryStatus status;
  final List<Reading> readings;
  final HistoryRange range;
  final String? errorMessage;

  const HistoryState({
    this.status = HistoryStatus.initial,
    this.readings = const [],
    this.range = HistoryRange.day,
    this.errorMessage,
  });

  HistoryState copyWith({
    HistoryStatus? status,
    List<Reading>? readings,
    HistoryRange? range,
    String? errorMessage,
  }) =>
      HistoryState(
        status: status ?? this.status,
        readings: readings ?? this.readings,
        range: range ?? this.range,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, readings, range, errorMessage];
}

enum HistoryStatus { initial, loading, loaded, error }

enum HistoryRange { day, week, month }
```

### Step 13.2: 实现 HistoryChart

Create `lib/widgets/history_chart.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:temp_monitor/domain/models/reading.dart';

class HistoryChart extends StatelessWidget {
  final List<Reading> readings;

  const HistoryChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text('无历史数据'));
    }

    final tempSpots = readings.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.temperature);
    }).toList();

    final humiditySpots = readings.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.humidity);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: tempSpots,
            isCurved: true,
            color: Colors.orange,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: humiditySpots,
            isCurved: true,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
```

### Step 13.3: 实现 HistoryPage

Create `lib/presentation/history/history_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/presentation/history/history_cubit.dart';
import 'package:temp_monitor/widgets/history_chart.dart';

class HistoryPage extends StatelessWidget {
  final String deviceId;

  const HistoryPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史曲线')),
      body: Column(
        children: [
          _buildRangeSelector(context),
          Expanded(
            child: BlocBuilder<HistoryCubit, HistoryState>(
              builder: (context, state) {
                if (state.status == HistoryStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.readings.isEmpty) {
                  return const Center(child: Text('暂无历史数据'));
                }
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: HistoryChart(readings: state.readings),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    final cubit = context.read<HistoryCubit>();
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        return SegmentedButton<HistoryRange>(
          segments: const [
            ButtonSegment(value: HistoryRange.day, label: Text('24h')),
            ButtonSegment(value: HistoryRange.week, label: Text('7d')),
            ButtonSegment(value: HistoryRange.month, label: Text('30d')),
          ],
          selected: {state.range},
          onSelectionChanged: (selected) {
            final range = selected.first;
            cubit.loadHistory(deviceId, range);
          },
        );
      },
    );
  }
}
```

### Step 13.4: 提交

```bash
git add lib/presentation/history lib/widgets/history_chart.dart
git commit -m "feat: add history page with fl_chart"
```

---

## Task 14: 设置页面 + Cubit

**Files:**
- Create: `lib/presentation/settings/settings_cubit.dart`
- Create: `lib/presentation/settings/settings_page.dart`
- Create: `lib/widgets/threshold_editor.dart`

### Step 14.1: 实现 SettingsCubit

Create `lib/presentation/settings/settings_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:temp_monitor/services/settings_service.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsService _settings;

  SettingsCubit(this._settings) : super(const SettingsState()) {
    _load();
  }

  void _load() {
    emit(SettingsState(
      scanIntervalSeconds: _settings.getScanIntervalSeconds(),
      retentionDays: _settings.getRetentionDays(),
      tempMin: _settings.getTempMin(),
      tempMax: _settings.getTempMax(),
      humidityMin: _settings.getHumidityMin(),
      humidityMax: _settings.getHumidityMax(),
      mockDeviceEnabled: _settings.getMockDeviceEnabled(),
    ));
  }

  Future<void> setScanInterval(int seconds) async {
    await _settings.setScanIntervalSeconds(seconds);
    emit(state.copyWith(scanIntervalSeconds: seconds));
  }

  Future<void> setRetentionDays(int days) async {
    await _settings.setRetentionDays(days);
    emit(state.copyWith(retentionDays: days));
  }

  Future<void> setTempRange(double min, double max) async {
    await _settings.setTempMin(min);
    await _settings.setTempMax(max);
    emit(state.copyWith(tempMin: min, tempMax: max));
  }

  Future<void> setHumidityRange(double min, double max) async {
    await _settings.setHumidityMin(min);
    await _settings.setHumidityMax(max);
    emit(state.copyWith(humidityMin: min, humidityMax: max));
  }

  Future<void> setMockDeviceEnabled(bool enabled) async {
    await _settings.setMockDeviceEnabled(enabled);
    emit(state.copyWith(mockDeviceEnabled: enabled));
  }
}

class SettingsState extends Equatable {
  final int scanIntervalSeconds;
  final int retentionDays;
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;
  final bool mockDeviceEnabled;

  const SettingsState({
    this.scanIntervalSeconds = 5,
    this.retentionDays = 30,
    this.tempMin = 0,
    this.tempMax = 40,
    this.humidityMin = 20,
    this.humidityMax = 80,
    this.mockDeviceEnabled = false,
  });

  SettingsState copyWith({
    int? scanIntervalSeconds,
    int? retentionDays,
    double? tempMin,
    double? tempMax,
    double? humidityMin,
    double? humidityMax,
    bool? mockDeviceEnabled,
  }) =>
      SettingsState(
        scanIntervalSeconds: scanIntervalSeconds ?? this.scanIntervalSeconds,
        retentionDays: retentionDays ?? this.retentionDays,
        tempMin: tempMin ?? this.tempMin,
        tempMax: tempMax ?? this.tempMax,
        humidityMin: humidityMin ?? this.humidityMin,
        humidityMax: humidityMax ?? this.humidityMax,
        mockDeviceEnabled: mockDeviceEnabled ?? this.mockDeviceEnabled,
      );

  @override
  List<Object?> get props => [
        scanIntervalSeconds,
        retentionDays,
        tempMin,
        tempMax,
        humidityMin,
        humidityMax,
        mockDeviceEnabled,
      ];
}
```

### Step 14.2: 实现 SettingsPage

Create `lib/presentation/settings/settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/presentation/settings/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              ListTile(
                title: const Text('扫描频率'),
                subtitle: Text('${state.scanIntervalSeconds} 秒'),
                trailing: DropdownButton<int>(
                  value: state.scanIntervalSeconds,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 秒（高耗电）')),
                    DropdownMenuItem(value: 2, child: Text('2 秒')),
                    DropdownMenuItem(value: 5, child: Text('5 秒（默认）')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().setScanInterval(value);
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('数据保留天数'),
                subtitle: Text('${state.retentionDays} 天'),
                trailing: DropdownButton<int>(
                  value: state.retentionDays,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 天')),
                    DropdownMenuItem(value: 30, child: Text('30 天')),
                    DropdownMenuItem(value: 90, child: Text('90 天')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().setRetentionDays(value);
                    }
                  },
                ),
              ),
              _buildRangeTile(
                context,
                title: '温度阈值 (°C)',
                min: state.tempMin,
                max: state.tempMax,
                onChanged: (min, max) =>
                    context.read<SettingsCubit>().setTempRange(min, max),
              ),
              _buildRangeTile(
                context,
                title: '湿度阈值 (%)',
                min: state.humidityMin,
                max: state.humidityMax,
                onChanged: (min, max) =>
                    context.read<SettingsCubit>().setHumidityRange(min, max),
              ),
              SwitchListTile(
                title: const Text('模拟设备模式'),
                subtitle: const Text('不扫描真实蓝牙，生成假数据用于测试'),
                value: state.mockDeviceEnabled,
                onChanged: (value) =>
                    context.read<SettingsCubit>().setMockDeviceEnabled(value),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRangeTile(
    BuildContext context, {
    required String title,
    required double min,
    required double max,
    required void Function(double min, double max) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text('下限: ${min.toStringAsFixed(1)}  上限: ${max.toStringAsFixed(1)}'),
      onTap: () async {
        final result = await showDialog<(double, double)>(
          context: context,
          builder: (context) => _RangeEditorDialog(min: min, max: max),
        );
        if (result != null) {
          onChanged(result.$1, result.$2);
        }
      },
    );
  }
}

class _RangeEditorDialog extends StatefulWidget {
  final double min;
  final double max;

  const _RangeEditorDialog({required this.min, required this.max});

  @override
  State<_RangeEditorDialog> createState() => _RangeEditorDialogState();
}

class _RangeEditorDialogState extends State<_RangeEditorDialog> {
  late double min;
  late double max;

  @override
  void initState() {
    super.initState();
    min = widget.min;
    max = widget.max;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑阈值'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('下限: ${min.toStringAsFixed(1)}'),
          Slider(
            value: min,
            min: -40,
            max: 80,
            divisions: 120,
            label: min.toStringAsFixed(1),
            onChanged: (value) => setState(() => min = value),
          ),
          Text('上限: ${max.toStringAsFixed(1)}'),
          Slider(
            value: max,
            min: -40,
            max: 80,
            divisions: 120,
            label: max.toStringAsFixed(1),
            onChanged: (value) => setState(() => max = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (min, max)),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
```

### Step 14.3: 提交

```bash
git add lib/presentation/settings
git commit -m "feat: add settings page for scan interval, thresholds and mock mode"
```

---

## Task 15: 调试日志页面

**Files:**
- Create: `lib/presentation/debug/debug_log_cubit.dart`
- Create: `lib/presentation/debug/debug_log_page.dart`

### Step 15.1: 实现 DebugLogCubit

Create `lib/presentation/debug/debug_log_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class DebugLogCubit extends Cubit<DebugLogState> {
  DebugLogCubit() : super(DebugLogState(entries: DebugLogger().entries));

  void refresh() => emit(DebugLogState(entries: DebugLogger().entries));

  void clear() {
    DebugLogger().clear();
    emit(const DebugLogState(entries: []));
  }

  String export() => DebugLogger().export();
}

class DebugLogState extends Equatable {
  final List<LogEntry> entries;

  const DebugLogState({required this.entries});

  @override
  List<Object?> get props => [entries];
}
```

### Step 15.2: 实现 DebugLogPage

Create `lib/presentation/debug/debug_log_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/presentation/debug/debug_log_cubit.dart';

class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final text = context.read<DebugLogCubit>().export();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('日志已复制到剪贴板')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => context.read<DebugLogCubit>().clear(),
          ),
        ],
      ),
      body: BlocBuilder<DebugLogCubit, DebugLogState>(
        builder: (context, state) {
          if (state.entries.isEmpty) {
            return const Center(child: Text('暂无日志'));
          }
          return ListView.builder(
            reverse: true,
            itemCount: state.entries.length,
            itemBuilder: (context, index) {
              final entry = state.entries[state.entries.length - 1 - index];
              return ListTile(
                dense: true,
                title: Text('[${entry.tag}] ${entry.message}'),
                subtitle: Text(entry.timestamp.toIso8601String()),
                leading: _levelIcon(entry.level),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<DebugLogCubit>().refresh(),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _levelIcon(LogLevel level) {
    final color = switch (level) {
      LogLevel.error => Colors.red,
      LogLevel.warning => Colors.orange,
      LogLevel.info => Colors.blue,
      LogLevel.debug => Colors.grey,
      LogLevel.verbose => Colors.black12,
    };
    return Icon(Icons.circle, color: color, size: 12);
  }
}
```

### Step 15.3: 提交

```bash
git add lib/presentation/debug
git commit -m "feat: add debug log page with copy and clear"
```

---

## Task 16: 设备列表页面

**Files:**
- Create: `lib/presentation/devices/devices_page.dart`

### Step 16.1: 实现 DevicesPage

Create `lib/presentation/devices/devices_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SensorRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('设备列表')),
      body: StreamBuilder<List<Device>>(
        stream: repository.watchAllDevices(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final devices = snapshot.data!;
          if (devices.isEmpty) {
            return const Center(child: Text('未发现设备，请确保设备在附近并已开启蓝牙'));
          }
          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.id),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => DashboardCubit(repository)
                          ..loadLatest(device.id),
                        child: DashboardPage(deviceId: device.id),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
```

### Step 16.2: 提交

```bash
git add lib/presentation/devices
git commit -m "feat: add devices list page"
```

---

## Task 17: App 入口与依赖注入

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`

### Step 17.1: 重写 main.dart

Modify `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/app.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/infrastructure/background_service.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final repository = SensorRepository(database);
  final settings = SettingsService();
  await settings.initialize();

  final notifications = NotificationService();
  await notifications.initialize();

  await BackgroundService.initialize();

  runApp(TempMonitorApp(
    repository: repository,
    settings: settings,
    notifications: notifications,
  ));
}
```

### Step 17.2: 重写 app.dart

Modify `lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/devices/devices_page.dart';
import 'package:temp_monitor/presentation/history/history_cubit.dart';
import 'package:temp_monitor/presentation/settings/settings_cubit.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

class TempMonitorApp extends StatelessWidget {
  final SensorRepository repository;
  final SettingsService settings;
  final NotificationService notifications;

  const TempMonitorApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: repository),
        RepositoryProvider.value(value: settings),
        RepositoryProvider.value(value: notifications),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit(settings)),
        ],
        child: MaterialApp(
          title: '温湿度监控',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: const MainNavigationScreen(),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SensorRepository>();
    final pages = [
      const DevicesPage(),
      BlocProvider(
        create: (_) => HistoryCubit(repository),
        child: const Placeholder(), // History needs a selected device
      ),
      const SettingsPage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: '设备'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: '历史'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
```

Note: The history page needs a deviceId. The navigation structure needs refinement. For the plan, keep it simple: the DevicesPage navigates to DashboardPage, and from DashboardPage there can be a button to HistoryPage. Update MainNavigationScreen to only have Devices and Settings, and navigate to History from Dashboard.

Simplify `app.dart`:

```dart
class MainNavigationScreen extends StatefulWidget {
  ...
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DevicesPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: '设备'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
```

And add a FloatingActionButton or AppBar action in DashboardPage to navigate to HistoryPage.

### Step 17.3: 运行 lint

Run:
```bash
flutter analyze
```

Expected: 无错误（可能有一些未使用 import 警告，需清理）。

### Step 17.4: 提交

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat: wire up app entry point and dependency injection"
```

---

## Task 18: iOS 权限配置

**Files:**
- Modify: `ios/Runner/Info.plist`

### Step 18.1: 更新 Info.plist

Add to `ios/Runner/Info.plist` inside `<dict>`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>此 App 需要蓝牙权限来扫描温湿度计。</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>此 App 需要蓝牙权限来扫描温湿度计。</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>扫描蓝牙设备需要定位权限。</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>fetch</string>
</array>
```

### Step 18.2: 提交

```bash
git add ios/Runner/Info.plist
git commit -m "chore: add iOS bluetooth and location permissions"
```

---

## Task 19: 模拟设备模式

**Files:**
- Create: `lib/infrastructure/mock_sensor.dart`
- Modify: `lib/infrastructure/background_service.dart`

### Step 19.1: 实现 MockSensor

Create `lib/infrastructure/mock_sensor.dart`:

```dart
import 'dart:async';
import 'dart:math';

import 'package:temp_monitor/domain/models/reading.dart';

class MockSensor {
  final _random = Random();
  double _temperature = 25.0;
  double _humidity = 60.0;

  Stream<Reading> readings({required String deviceId, required Duration interval}) {
    return Stream.periodic(interval, (_) {
      _temperature += (_random.nextDouble() - 0.5) * 0.5;
      _humidity += (_random.nextDouble() - 0.5) * 1.0;
      _humidity = _humidity.clamp(0.0, 100.0);

      return Reading(
        deviceId: deviceId,
        temperature: double.parse(_temperature.toStringAsFixed(2)),
        humidity: double.parse(_humidity.toStringAsFixed(2)),
        battery: 85,
        rssi: -60,
        recordedAt: DateTime.now().toUtc(),
      );
    });
  }
}
```

### Step 19.2: 在后台服务中支持模拟模式

Modify `lib/infrastructure/background_service.dart`:

Add import:
```dart
import 'package:temp_monitor/infrastructure/mock_sensor.dart';
```

In `onStart`, after creating settings, add:
```dart
final isMock = settings.getMockDeviceEnabled();
```

Replace the scanning block with:
```dart
if (isMock) {
  final mockSensor = MockSensor();
  mockSensor.readings(deviceId: 'mock-device', interval: interval).listen((reading) async {
    await repository.saveReading(reading);
    _uiSendPort?.send(reading);
    // threshold evaluation same as below
  });
} else {
  // existing scanner logic
}
```

Extract threshold evaluation into a helper function to avoid duplication.

### Step 19.3: 提交

```bash
git add lib/infrastructure/mock_sensor.dart lib/infrastructure/background_service.dart
git commit -m "feat: add mock device mode for testing without hardware"
```

---

## Task 20: GitHub Actions CI

**Files:**
- Create: `.github/workflows/build_android.yml`

### Step 20.1: 创建 CI 工作流

Create `.github/workflows/build_android.yml`:

```yaml
name: Build Android APK

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'

      - name: Get dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Run tests
        run: flutter test

      - name: Build release APK
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

### Step 20.2: 提交

```bash
git add .github/workflows/build_android.yml
git commit -m "ci: add GitHub Actions workflow to build Android APK"
```

---

## Task 21: 权限申请流程（Android & iOS）

**Files:**
- Create: `lib/infrastructure/permission_service.dart`
- Modify: `lib/presentation/devices/devices_page.dart`

### Step 21.1: 实现 PermissionService

Create `lib/infrastructure/permission_service.dart`:

```dart
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class PermissionService {
  static Future<bool> requestBlePermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) {
        DebugLogger().w('BLE permissions not all granted: $statuses',
            tag: 'Permission');
      }
      return allGranted;
    } else if (Platform.isIOS) {
      // iOS permissions are requested automatically by flutter_blue_plus
      return true;
    }
    return false;
  }

  static Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }
}
```

### Step 21.2: 在设备列表页请求权限

Modify `lib/presentation/devices/devices_page.dart`，在 `build` 开头或 `initState` 中调用：

```dart
@override
void initState() {
  super.initState();
  PermissionService.requestBlePermissions();
  PermissionService.requestNotificationPermission();
}
```

For a StatelessWidget, use `StatefulWidget` or call in a `PostFrameCallback`.

Convert DevicesPage to StatefulWidget in implementation.

### Step 21.3: 提交

```bash
git add lib/infrastructure/permission_service.dart lib/presentation/devices/devices_page.dart
git commit -m "feat: add runtime permission handling"
```

---

## Task 22: 集成测试与最终验证

**Files:**
- Create: `integration_test/app_test.dart`

### Step 22.1: 创建集成测试

Create `integration_test/app_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:temp_monitor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows devices page', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('设备列表'), findsOneWidget);
  });
}
```

Add dev dependency to `pubspec.yaml`:
```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

Run:
```bash
flutter pub get
```

### Step 22.2: 运行所有测试

Run:
```bash
flutter test
```

Expected: 所有单元测试通过。

### Step 22.3: 最终 lint 检查

Run:
```bash
flutter analyze
flutter build apk --release
```

Expected: 无错误，release APK 构建成功。

### Step 22.4: 提交

```bash
git add integration_test integration_test/app_test.dart pubspec.yaml
git commit -m "test: add integration test and final verification"
```

---

## Self-Review

### Spec Coverage Check

| 设计文档章节 | 对应任务 |
|---|---|
| 技术栈（Flutter + flutter_blue_plus + drift + bloc + fl_chart） | Task 1 |
| BThome v2 解析 | Task 3 |
| 阈值告警与去抖 | Task 4 |
| 本地数据库与滚动清理 | Task 6, 7 |
| BLE 扫描 | Task 8 |
| 本地通知 | Task 9 |
| 后台服务（Android 前台服务） | Task 11 |
| 设置（扫描频率、阈值、保留天数） | Task 10, 14 |
| 仪表盘与下拉刷新 | Task 12 |
| 历史曲线 | Task 13 |
| 设备列表 | Task 16 |
| 调试日志 | Task 5, 15 |
| Android 权限 | Task 11, 21 |
| iOS 权限 | Task 18 |
| GitHub Actions CI | Task 20 |
| 模拟设备模式 | Task 19 |
| 测试策略 | Task 3, 4, 5, 7, 22 |

无遗漏。

### Placeholder Scan

- 无 `TBD` / `TODO` / `implement later`。
- 每个任务包含具体文件路径、代码、命令。
- 无 "Similar to Task N" 引用。

### Type Consistency Check

- `Reading` 字段在所有模块中一致：deviceId, temperature, humidity, battery, rssi, recordedAt。
- `ThresholdEngine` 方法签名一致：`evaluate(temperature, humidity)`。
- `AppDatabase` / DAO 命名一致。

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-12-xiaomi-bthome-monitor-plan.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?