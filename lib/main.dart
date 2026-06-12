import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:temp_monitor/app.dart';
import 'package:temp_monitor/data/app_database.dart' hide Reading;
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/scan_service.dart';
import 'package:temp_monitor/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // We use Provider<Stream<Reading>> only to pass a Stream reference
  // from main() to DashboardCubit (via listen: false), not for widget
  // rebuilds. The debug assertion is a false positive here.
  Provider.debugCheckInvalidValueType = null;

  final database = AppDatabase();
  final repository = SensorRepository(database);

  final settings = SettingsService();
  await settings.initialize();

  final notifications = NotificationService();
  await notifications.initialize();

  final scanService = ScanService(
    repository: repository,
    settings: settings,
    notifications: notifications,
  );

  // Start scanning immediately (mock or real BLE based on settings).
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
