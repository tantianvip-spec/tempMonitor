import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/history/history_enums.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SensorRepository _repository;
  final Stream<Reading>? _readingStream;
  StreamSubscription<Reading>? _realTimeSubscription;
  StreamSubscription<List<Device>>? _devicesSubscription;

  DashboardCubit(
    this._repository, {
    Stream<Reading>? readingStream,
  })  : _readingStream = readingStream,
        super(const DashboardState()) {
    _init();
  }

  void _init() {
    _devicesSubscription = _repository.watchAllDevices().listen((devices) {
      if (isClosed) return;
      final oldIndex = state.currentDeviceIndex;
      emit(state.copyWith(devices: devices));
      if (devices.isEmpty) return;
      final newIndex = oldIndex < devices.length ? oldIndex : 0;
      if (newIndex != oldIndex || state.latestReading == null) {
        switchToDevice(newIndex);
      }
    });
  }

  void switchToDevice(int index) {
    if (index < 0 || index >= state.devices.length) return;
    emit(state.copyWith(currentDeviceIndex: index));
    _loadCurrentDeviceData(state.devices[index].id);
  }

  Future<void> _loadCurrentDeviceData(String deviceId) async {
    final latest = await _repository.getLatestReading(deviceId);
    if (!isClosed) {
      emit(state.copyWith(latestReading: latest));
    }

    await _loadHistory(deviceId, state.range);

    _realTimeSubscription?.cancel();
    if (_readingStream != null) {
      _realTimeSubscription = _readingStream!
          .where((r) => r.deviceId == deviceId)
          .listen(onNewReading);
    }
  }

  Future<void> _loadHistory(String deviceId, HistoryRange range) async {
    emit(state.copyWith(historyStatus: HistoryStatus.loading));
    try {
      final now = DateTime.now();
      final from = switch (range) {
        HistoryRange.day => now.subtract(const Duration(hours: 24)),
        HistoryRange.week => now.subtract(const Duration(days: 7)),
        HistoryRange.month => now.subtract(const Duration(days: 30)),
      };
      final readings = await _repository.getReadingsForDevice(
        deviceId,
        from: from,
        to: now,
      );
      if (!isClosed) {
        emit(state.copyWith(
          historyStatus: HistoryStatus.loaded,
          historyReadings: readings,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          historyStatus: HistoryStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  void changeHistoryRange(HistoryRange range) {
    emit(state.copyWith(range: range));
    final deviceId = _currentDeviceId;
    if (deviceId != null) _loadHistory(deviceId, range);
  }

  void onNewReading(Reading reading) {
    emit(state.copyWith(latestReading: reading));
    if (state.historyStatus == HistoryStatus.loaded) {
      final history = [...state.historyReadings, reading];
      emit(state.copyWith(historyReadings: history));
    }
  }

  String? get _currentDeviceId {
    final idx = state.currentDeviceIndex;
    if (idx < 0 || idx >= state.devices.length) return null;
    return state.devices[idx].id;
  }

  @override
  Future<void> close() async {
    await _realTimeSubscription?.cancel();
    await _devicesSubscription?.cancel();
    return super.close();
  }
}

class DashboardState extends Equatable {
  final List<Device> devices;
  final int currentDeviceIndex;
  final Reading? latestReading;
  final List<Reading> historyReadings;
  final HistoryStatus historyStatus;
  final HistoryRange range;
  final String? errorMessage;

  const DashboardState({
    this.devices = const [],
    this.currentDeviceIndex = 0,
    this.latestReading,
    this.historyReadings = const [],
    this.historyStatus = HistoryStatus.initial,
    this.range = HistoryRange.day,
    this.errorMessage,
  });

  DashboardState copyWith({
    List<Device>? devices,
    int? currentDeviceIndex,
    Reading? latestReading,
    List<Reading>? historyReadings,
    HistoryStatus? historyStatus,
    HistoryRange? range,
    String? errorMessage,
  }) =>
      DashboardState(
        devices: devices ?? this.devices,
        currentDeviceIndex: currentDeviceIndex ?? this.currentDeviceIndex,
        latestReading: latestReading ?? this.latestReading,
        historyReadings: historyReadings ?? this.historyReadings,
        historyStatus: historyStatus ?? this.historyStatus,
        range: range ?? this.range,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [
        devices,
        currentDeviceIndex,
        latestReading,
        historyReadings,
        historyStatus,
        range,
        errorMessage,
      ];
}
