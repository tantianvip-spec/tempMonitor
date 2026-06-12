import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/services/settings_service.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsService _settings;

  SettingsCubit(this._settings) : super(const SettingsState()) {
    _load();
  }

  void _load() {
    emit(SettingsState(
      scanIntervalSeconds: _settings.getScanIntervalSeconds(),
      retentionDays: _settings.getRetentionDays(),
      tempMin: _settings.getTempMin(),
      tempMax: _settings.getTempMax(),
      humidityMin: _settings.getHumidityMin(),
      humidityMax: _settings.getHumidityMax(),
      mockDeviceEnabled: _settings.getMockDeviceEnabled(),
    ));
  }

  Future<void> setScanInterval(int seconds) async {
    await _settings.setScanIntervalSeconds(seconds);
    emit(state.copyWith(scanIntervalSeconds: seconds));
  }

  Future<void> setRetentionDays(int days) async {
    await _settings.setRetentionDays(days);
    emit(state.copyWith(retentionDays: days));
  }

  Future<void> setTempRange(double min, double max) async {
    await _settings.setTempMin(min);
    await _settings.setTempMax(max);
    emit(state.copyWith(tempMin: min, tempMax: max));
  }

  Future<void> setHumidityRange(double min, double max) async {
    await _settings.setHumidityMin(min);
    await _settings.setHumidityMax(max);
    emit(state.copyWith(humidityMin: min, humidityMax: max));
  }

  Future<void> setMockDeviceEnabled(bool enabled) async {
    await _settings.setMockDeviceEnabled(enabled);
    emit(state.copyWith(mockDeviceEnabled: enabled));
  }
}

class SettingsState extends Equatable {
  final int scanIntervalSeconds;
  final int retentionDays;
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;
  final bool mockDeviceEnabled;

  const SettingsState({
    this.scanIntervalSeconds = 5,
    this.retentionDays = 30,
    this.tempMin = 0,
    this.tempMax = 40,
    this.humidityMin = 20,
    this.humidityMax = 80,
    this.mockDeviceEnabled = false,
  });

  SettingsState copyWith({
    int? scanIntervalSeconds,
    int? retentionDays,
    double? tempMin,
    double? tempMax,
    double? humidityMin,
    double? humidityMax,
    bool? mockDeviceEnabled,
  }) =>
      SettingsState(
        scanIntervalSeconds: scanIntervalSeconds ?? this.scanIntervalSeconds,
        retentionDays: retentionDays ?? this.retentionDays,
        tempMin: tempMin ?? this.tempMin,
        tempMax: tempMax ?? this.tempMax,
        humidityMin: humidityMin ?? this.humidityMin,
        humidityMax: humidityMax ?? this.humidityMax,
        mockDeviceEnabled: mockDeviceEnabled ?? this.mockDeviceEnabled,
      );

  @override
  List<Object?> get props => [
        scanIntervalSeconds,
        retentionDays,
        tempMin,
        tempMax,
        humidityMin,
        humidityMax,
        mockDeviceEnabled,
      ];
}
