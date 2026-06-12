import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SensorRepository _repository;
  final Stream<Reading>? _readingStream;
  StreamSubscription<Reading>? _subscription;

  DashboardCubit(this._repository, {Stream<Reading>? readingStream})
      : _readingStream = readingStream,
        super(const DashboardState());

  Future<void> loadLatest(String deviceId) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      final reading = await _repository.getLatestReading(deviceId);
      emit(state.copyWith(
        status: DashboardStatus.loaded,
        latestReading: reading,
      ));
      // Subscribe to real-time pushes from the background isolate now
      // that we know which device this dashboard is bound to. Skip if a
      // subscription was already set up for a previous load.
      if (_subscription == null && _readingStream != null) {
        _subscription = _readingStream!
            .where((r) => r.deviceId == deviceId)
            .listen(onNewReading);
      }
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void onNewReading(Reading reading) {
    emit(state.copyWith(
      status: DashboardStatus.loaded,
      latestReading: reading,
    ));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

enum DashboardStatus { initial, loading, loaded, error }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final Reading? latestReading;
  final String? errorMessage;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.latestReading,
    this.errorMessage,
  });

  DashboardState copyWith({
    DashboardStatus? status,
    Reading? latestReading,
    String? errorMessage,
  }) =>
      DashboardState(
        status: status ?? this.status,
        latestReading: latestReading ?? this.latestReading,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, latestReading, errorMessage];
}
