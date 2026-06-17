import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:temp_monitor/app.dart';
import 'package:temp_monitor/data/app_database.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/presentation/settings/settings_page.dart';
import 'package:temp_monitor/services/scan_service.dart';
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

  testWidgets('App boots with 3-tab navigation and debug entry in settings', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = SensorRepository(db);
    final settings = SettingsService();
    await settings.initialize();
    final notifications = NotificationService();
    final scanService = ScanService(
      repository: repo,
      settings: settings,
      notifications: notifications,
    );
    // Skip notifications.initialize() — flutter_local_notifications needs
    // platform binding for plugin registration. The widget tree doesn't
    // depend on the plugin being initialized for the boot smoke test.

    await tester.pumpWidget(TempMonitorApp(
      repository: repo,
      settings: settings,
      notifications: notifications,
      scanService: scanService,
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('仪表盘')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('设备')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('设置')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('调试')),
      findsNothing,
    );

    // Navigate to settings and scroll to the debug entry.
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('设置'),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('调试日志'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.descendant(of: find.byType(SettingsPage), matching: find.text('调试日志')),
      findsOneWidget,
    );

    await db.close();
    scanService.dispose();
  });
}
