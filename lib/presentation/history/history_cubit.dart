import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final SensorRepository _repository;

  HistoryCubit(this._repository) : super(const HistoryState());

  Future<void> loadHistory(String deviceId, HistoryRange range) async {
    emit(state.copyWith(status: HistoryStatus.loading));
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

      emit(state.copyWith(
        status: HistoryStatus.loaded,
        readings: readings,
        range: range,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}

enum HistoryStatus { initial, loading, loaded, error }

enum HistoryRange { day, week, month }

class HistoryState extends Equatable {
  final HistoryStatus status;
  final List<Reading> readings;
  final HistoryRange range;
  final String? errorMessage;

  const HistoryState({
    this.status = HistoryStatus.initial,
    this.readings = const [],
    this.range = HistoryRange.day,
    this.errorMessage,
  });

  HistoryState copyWith({
    HistoryStatus? status,
    List<Reading>? readings,
    HistoryRange? range,
    String? errorMessage,
  }) =>
      HistoryState(
        status: status ?? this.status,
        readings: readings ?? this.readings,
        range: range ?? this.range,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, readings, range, errorMessage];
}