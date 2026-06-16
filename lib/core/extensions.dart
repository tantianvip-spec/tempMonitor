import 'package:intl/intl.dart';

extension DateTimeFormat on DateTime {
  String toDisplayString() =>
      DateFormat('MM-dd HH:mm').format(toLocal());
  String toLogString() =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(toLocal());

  /// Coarse human-readable "time since" string, Chinese.
  ///   <60s   → "刚刚"
  ///   <60m   → "N 分钟前"
  ///   <24h   → "N 小时前"
  ///   else   → MM-dd HH:mm
  String toAgoString({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final delta = reference.difference(this);
    if (delta.inSeconds < 60) return '刚刚';
    if (delta.inMinutes < 60) return '${delta.inMinutes} 分钟前';
    if (delta.inHours < 24) return '${delta.inHours} 小时前';
    return toDisplayString();
  }
}

extension DoubleFormat on double {
  String toTempString() => '${toStringAsFixed(1)}°C';
  String toHumidityString() => '${toStringAsFixed(1)}%';
}

extension NullableDoubleFormat on double? {
  String toTempString() => this == null ? '--°C' : this!.toTempString();
  String toHumidityString() => this == null ? '--%' : this!.toHumidityString();
}
