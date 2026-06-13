abstract class AppConstants {
  static const String bthomeServiceUuid = '0000fcd2-0000-1000-8000-00805f9b34fb';
  static const int defaultScanIntervalSeconds = 300;
  static const int defaultRetentionDays = 30;
  static const double defaultTempMin = 0.0;
  static const double defaultTempMax = 40.0;
  static const double defaultHumidityMin = 20.0;
  static const double defaultHumidityMax = 80.0;
  static const int maxLogEntries = 1000;
  static const String uiIsolatePortName = 'temp_monitor_ui_port';
}
