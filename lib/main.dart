import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:temp_monitor/app.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/data/app_database.dart' hide Reading;
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/infrastructure/background_service.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
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

  await BackgroundService.initialize();

  // Real-time push channel: background isolate sends Reading objects;
  // UI isolate receives them and forwards to a broadcast stream the
  // DashboardCubit can listen to.
  // IMPORTANT: register the port BEFORE starting the service so the
  // background isolate can find it on first tick.
  final receivePort = ReceivePort();
  IsolateNameServer.removePortNameMapping(AppConstants.uiIsolatePortName);
  IsolateNameServer.registerPortWithName(
    receivePort.sendPort,
    AppConstants.uiIsolatePortName,
  );
  final readingStream = receivePort.cast<Reading>().asBroadcastStream();

  // Start the background service (scan loop, mock mode, etc.). Only
  // start if not already running to avoid duplicate state.
  if (!await FlutterBackgroundService().isRunning()) {
    await FlutterBackgroundService().startService();
  }

  // Save each incoming Reading into the UI-side database so the
  // reactive watchAllDevices() stream on the devices page fires.
  // The background isolate writes to its own database instance, so
  // the UI isolate must persist reads locally to see them.
  readingStream.listen((reading) {
    repository.saveReading(reading).catchError((e) {
      DebugLogger().e('Failed to persist reading in UI isolate: $e',
          tag: 'App');
    });
  });

  DebugLogger().i('App initialized', tag: 'App');

  runApp(TempMonitorApp(
    repository: repository,
    settings: settings,
    notifications: notifications,
    readingStream: readingStream,
  ));
}
