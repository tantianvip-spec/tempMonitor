import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:temp_monitor/core/constants.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

/// Manages a persistent foreground service that keeps the Android process
/// alive so the main isolate's BLE scanning Timer continues to fire even
/// when the app is backgrounded.
///
/// This service runs in its own Dart isolate but does NOT perform any BLE
/// scanning — all scanning happens in the main isolate via [ScanService].
/// The background isolate only sends periodic heartbeats (`null` messages)
/// to the main isolate to confirm the process is alive.
class BackgroundService {
  static const int _notificationId = 888;
  static const String _channelId = 'temp_monitor_service';
  static const String _channelName = '温湿度监控服务';
  static const String _channelDesc = '后台服务运行中';
  static bool _configured = false;

  /// Whether the background service was successfully configured and is
  /// available for use. Check before calling [start] if you need a
  /// fallback path.
  static bool get isAvailable => _configured;

  /// Initialize the background service configuration.
  /// This must be called once during app startup (before [start]).
  ///
  /// Pre-creates the notification channel via flutter_local_notifications
  /// so the background service plugin's Java code can use it immediately
  /// in onCreate() without needing to auto-create "FOREGROUND_DEFAULT".
  /// This avoids a race condition where SharedPreferences may not have
  /// been flushed before the service reads them.
  static Future<void> initialize() async {
    if (_configured) return;

    // Pre-create the notification channel so the plugin's Java
    // BackgroundService.onCreate() finds it already exists. This is
    // critical on Android 15+ (API 35) where FOREGROUND_SERVICE_TYPE_MANIFEST
    // is deprecated: if the plugin's SharedPreferences read returns null
    // for foreground_service_types (which can happen due to apply()'s
    // async write), it falls back to the deprecated type and
    // startForeground() is silently rejected, causing the 5-second
    // ForegroundServiceDidNotStartInTimeException crash.
    final androidPlugin = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.low,
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        // Use a pre-created channel so the plugin's Java code skips
        // auto-creating "FOREGROUND_DEFAULT" in onCreate(). A custom
        // channel ID forces the plugin to trust the app has created it,
        // avoiding the race between channel creation and startForeground().
        notificationChannelId: _channelId,
        initialNotificationTitle: '温湿度监控',
        initialNotificationContent: '正在后台监听设备...',
        foregroundServiceNotificationId: _notificationId,
        // Do NOT pass foregroundServiceTypes here. The plugin persists the
        // chosen types in SharedPreferences and reuses them on subsequent
        // service starts (including boot and watchdog restarts). If a user
        // previously had an older build that stored "location", the plugin
        // would request FOREGROUND_SERVICE_TYPE_LOCATION (0x08) while the
        // manifest only declares dataSync (0x01), causing:
        //   IllegalArgumentException: foregroundServiceType 0x08 is not a subset of 0x01
        // Leaving this null makes the plugin use FOREGROUND_SERVICE_TYPE_MANIFEST,
        // so ServiceCompat reads the type from AndroidManifest.xml where we
        // declare dataSync. configure() also clears the cached value.
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    _configured = true;
  }

  /// Start the foreground service.
  static Future<void> start() async {
    if (!_configured) return;
    final service = FlutterBackgroundService();
    await service.startService();
  }

  /// Stop the foreground service.
  static void stop() {
    if (!_configured) return;
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    } catch (_) {}
  }

  /// Send updated settings to the running background service.
  static void updateSettings() {
    if (!_configured) return;
    try {
      final service = FlutterBackgroundService();
      service.invoke('updateSettings');
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    try {
      DartPluginRegistrant.ensureInitialized();

      // Show the foreground service notification so Android keeps the
      // process alive.
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '温湿度监控',
          content: '正在后台监听设备...',
        );
        await service.setAsForegroundService();
      }

      DebugLogger().i(
          'Background service started — process keepalive only, '
          'BLE scanning runs in main isolate',
          tag: 'BackgroundService');

      // The UI isolate registers a ReceivePort under this name when it
      // starts. Look it up each tick so a UI hot-restart (which
      // re-registers) is picked up.
      SendPort? uiPort;

      // Send a heartbeat every 5 minutes to confirm the process is alive.
      // The heartbeat interval is fixed (not tied to the scan interval)
      // because this is purely a process-liveness signal.
      const heartbeatInterval = Duration(seconds: 300);
      Timer? heartbeatTimer;

      void startHeartbeat() {
        heartbeatTimer?.cancel();
        DebugLogger().i(
            'Heartbeat every ${heartbeatInterval.inSeconds}s',
            tag: 'BackgroundService');

        // Send first heartbeat immediately to confirm alive at startup.
        uiPort ??= IsolateNameServer.lookupPortByName(
            AppConstants.uiIsolatePortName);
        uiPort?.send(null);

        heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
          uiPort ??= IsolateNameServer.lookupPortByName(
              AppConstants.uiIsolatePortName);
          if (uiPort != null) {
            uiPort!.send(null);
            DebugLogger().v('Heartbeat sent', tag: 'BackgroundService');
          } else {
            DebugLogger().v(
                'Heartbeat skipped — no uiPort registered',
                tag: 'BackgroundService');
          }
        });
      }

      service.on('stopService').listen((event) {
        DebugLogger().i(
            'Background service stopping', tag: 'BackgroundService');
        heartbeatTimer?.cancel();
        service.stopSelf();
      });

      service.on('updateSettings').listen((event) {
        DebugLogger().i(
            'Background service updateSettings received (heartbeat unchanged)',
            tag: 'BackgroundService');
        // Heartbeat interval is fixed; nothing to re-read.
      });

      startHeartbeat();
    } catch (e, s) {
      DebugLogger().e(
        'BackgroundService onStart error: $e\n$s',
        tag: 'BackgroundService',
      );
    }
  }
}
