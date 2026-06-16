import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_monitor/core/constants.dart';

class SettingsService {
  late final SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Theme mode ───────────────────────────────────────────────
  ThemeMode getThemeMode() {
    final raw = _prefs.getString('theme_mode');
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await _prefs.setString('theme_mode', raw);
  }

  // ── Scan & storage ───────────────────────────────────────────
  int getScanIntervalSeconds() {
    return _prefs.getInt('scan_interval_seconds') ??
        AppConstants.defaultScanIntervalSeconds;
  }

  Future<void> setScanIntervalSeconds(int value) async {
    await _prefs.setInt('scan_interval_seconds', value);
  }

  int getRetentionDays() {
    return _prefs.getInt('retention_days') ?? AppConstants.defaultRetentionDays;
  }

  Future<void> setRetentionDays(int value) async {
    await _prefs.setInt('retention_days', value);
  }

  double getTempMin() =>
      _prefs.getDouble('temp_min') ?? AppConstants.defaultTempMin;
  Future<void> setTempMin(double value) async =>
      _prefs.setDouble('temp_min', value);

  double getTempMax() =>
      _prefs.getDouble('temp_max') ?? AppConstants.defaultTempMax;
  Future<void> setTempMax(double value) async =>
      _prefs.setDouble('temp_max', value);

  double getHumidityMin() =>
      _prefs.getDouble('humidity_min') ?? AppConstants.defaultHumidityMin;
  Future<void> setHumidityMin(double value) async =>
      _prefs.setDouble('humidity_min', value);

  double getHumidityMax() =>
      _prefs.getDouble('humidity_max') ?? AppConstants.defaultHumidityMax;
  Future<void> setHumidityMax(double value) async =>
      _prefs.setDouble('humidity_max', value);

  bool getMockDeviceEnabled() => _prefs.getBool('mock_device_enabled') ?? false;
  Future<void> setMockDeviceEnabled(bool value) async =>
      _prefs.setBool('mock_device_enabled', value);
}
