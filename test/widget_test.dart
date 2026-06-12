import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:temp_monitor/app.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/settings_service.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots with main navigation', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = SensorRepository(db);
    final settings = SettingsService();
    await settings.initialize();
    final notifications = NotificationService();
    // Skip notifications.initialize() — flutter_local_notifications needs
    // platform binding for plugin registration. The widget tree doesn't
    // depend on the plugin being initialized for the boot smoke test.

    await tester.pumpWidget(TempMonitorApp(
      repository: repo,
      settings: settings,
      notifications: notifications,
    ));
    await tester.pumpAndSettle();

    expect(find.text('设备'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('调试'), findsOneWidget);

    await db.close();
  });
}
