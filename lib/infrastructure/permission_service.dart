import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

/// Requests the runtime permissions the app needs at startup.
///
/// - **Android:** `bluetooth_scan`, `bluetooth_connect`, `location_when_in_use`
///   for BLE scanning, plus `notification` for local alerts.
/// - **iOS:** permissions are requested automatically by `flutter_blue_plus`
///   when the system framework first touches BLE. No Dart-side request needed.
class PermissionService {
  /// Requests BLE-related runtime permissions. Returns `true` when all
  /// required permissions have been granted.
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
    }
    // iOS permissions are prompted by the BLE framework automatically
    // on first scan — no explicit Dart request needed.
    return true;
  }

  /// Requests notification permission (Android 13+ runtime permission;
  /// iOS prompts automatically when the notification plugin initializes).
  static Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }
}