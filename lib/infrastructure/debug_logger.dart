import 'dart:collection';

enum LogLevel { verbose, debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  String toLogLine() {
    final levelStr = level.name.toUpperCase().padRight(7);
    final timeStr = timestamp.toIso8601String();
    return '[$timeStr] $levelStr [$tag] $message';
  }
}

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final int _maxEntries = 1000;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => UnmodifiableListView(_entries);

  void log(
    String message, {
    LogLevel level = LogLevel.info,
    String tag = 'App',
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  void v(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.verbose, tag: tag);
  void d(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.debug, tag: tag);
  void i(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.info, tag: tag);
  void w(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.warning, tag: tag);
  void e(String message, {String tag = 'App'}) =>
      log(message, level: LogLevel.error, tag: tag);

  String export() => _entries.map((e) => e.toLogLine()).join('\n');

  void clear() => _entries.clear();
}
