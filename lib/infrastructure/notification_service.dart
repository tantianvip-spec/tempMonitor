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
