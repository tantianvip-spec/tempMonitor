import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

class DebugLogCubit extends Cubit<DebugLogState> {
  DebugLogCubit()
      : super(DebugLogState(
          entries: List.unmodifiable(DebugLogger().entries),
        ));

  /// Snapshot the singleton's current entries into a fresh unmodifiable
  /// list so Equatable's list equality treats it as a new value and
  /// rebuilds subscribers (the singleton always returns the same
  /// UnmodifiableListView instance, which would otherwise compare equal).
  void refresh() => emit(DebugLogState(
        entries: List.unmodifiable(DebugLogger().entries),
      ));

  void clear() {
    DebugLogger().clear();
    emit(const DebugLogState(entries: []));
  }

  String export() => DebugLogger().export();
}

class DebugLogState extends Equatable {
  final List<LogEntry> entries;

  const DebugLogState({required this.entries});

  @override
  List<Object?> get props => [entries];
}
