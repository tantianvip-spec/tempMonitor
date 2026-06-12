import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class NotificationService {
  /// Stable channel identity used by both the channel registration and
  /// every subsequent `show()` call — they must agree exactly.
  static const String _alertChannelId = 'temp_monitor_alerts';
  static const String _alertChannelName = '温湿度告警';
  static const String _alertChannelDescription = '温湿度超出设定范围时的提醒';

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

    // Android 8+ requires channels to exist before posting a notification.
    // Lazy creation on first `show()` works in practice but races with
    // the first alert; do it eagerly so a breach immediately after boot
    // is delivered, not silently dropped.
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      const channel = AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: _alertChannelDescription,
        importance: Importance.high,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  Future<void> showAlert({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      DebugLogger().w('NotificationService not initialized', tag: 'Notification');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: _alertChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
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
