import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:temp_monitor/app.dart';
import 'package:temp_monitor/data/app_database.dart' hide Reading;
import 'package:temp_monitor/infrastructure/background_service.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/permission_service.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/scan_service.dart';
import 'package:temp_monitor/services/settings_service.dart';

void main() async {
  // Catch and log ALL errors — including widget-layer crashes — so we
  // can see what's going wrong even if the app keeps crashing.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DebugLogger().e(
      'FlutterError: ${details.exception}\n${details.stack}',
      tag: 'App',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DebugLogger().e('Platform error: $error\n$stack', tag: 'App');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  // We use Provider<Stream<Reading>> only to pass a Stream reference
  // from main() to DashboardCubit (via listen: false), not for widget
  // rebuilds. The debug assertion is a false positive here.
  Provider.debugCheckInvalidValueType = null;

  // Initialize the background service first so it can start scanning
  // in its own isolate before the UI is ready.
  await BackgroundService.initialize();

  AppDatabase? database;
  try {
    database = AppDatabase();
  } catch (e) {
    DebugLogger().e('Failed to open database: $e', tag: 'App');
    rethrow;
  }
  final repository = SensorRepository(database);

  final settings = SettingsService();
  await settings.initialize();

  final notifications = NotificationService();
  await notifications.initialize();

  final scanService = ScanService(
    repository: repository,
    settings: settings,
  );

  // Request BLE permissions before starting the scan loop.
  // On Android 12+, BLUETOOTH_SCAN permission is required for
  // flutter_blue_plus.startScan() to work.
  await PermissionService.requestBlePermissions();

  // Auto-start scanning — starts the background service for periodic
  // BLE scanning and sets up the isolate port bridge.
  scanService.start();

  DebugLogger().i('App initialized', tag: 'App');

  runApp(TempMonitorApp(
    repository: repository,
    settings: settings,
    notifications: notifications,
    readingStream: scanService.readingStream,
    scanService: scanService,
  ));
}
