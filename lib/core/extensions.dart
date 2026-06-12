import 'package:intl/intl.dart';

extension DateTimeFormat on DateTime {
  String toDisplayString() => DateFormat('MM-dd HH:mm').format(this);
  String toLogString() => DateFormat('yyyy-MM-dd HH:mm:ss').format(this);
}

extension DoubleFormat on double {
  String toTempString() => '${toStringAsFixed(1)}°C';
  String toHumidityString() => '${toStringAsFixed(1)}%';
}
