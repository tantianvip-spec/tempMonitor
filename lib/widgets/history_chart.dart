import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/history/history_cubit.dart';

class HistoryChart extends StatelessWidget {
  final List<Reading> readings;
  final HistoryRange range;

  const HistoryChart({
    super.key,
    required this.readings,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text('无历史数据'));
    }

    final axisLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted(context),
          fontSize: 10,
        );

    // Separate temperature and humidity readings — each chart shows only
    // the points where that metric was present.
    final tempReadings =
        readings.where((r) => r.temperature != null).toList();
    final humReadings =
        readings.where((r) => r.humidity != null).toList();

    final allTimes =
        readings.map((r) => r.recordedAt.millisecondsSinceEpoch.toDouble());
    final timeMin = allTimes.reduce((a, b) => a < b ? a : b);
    final timeMax = allTimes.reduce((a, b) => a > b ? a : b);
    final timeSpan = timeMax - timeMin;
    final temps = tempReadings.map((r) => r.temperature!).toList();
    final hums = humReadings.map((r) => r.humidity!).toList();
    final tempTimes = tempReadings
        .map((r) => r.recordedAt.millisecondsSinceEpoch.toDouble())
        .toList();
    final humTimes = humReadings
        .map((r) => r.recordedAt.millisecondsSinceEpoch.toDouble())
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      children: [
        if (temps.isNotEmpty)
          _ChartSection(
            title: '温度',
            icon: Icons.thermostat,
            color: AppTheme.accentTemp,
            currentValue: '${temps.last.toStringAsFixed(1)}°C',
            chart: _buildChart(
              context: context,
              values: temps,
              times: tempTimes,
              timeMin: timeMin,
              timeSpan: timeSpan,
              color: AppTheme.accentTemp,
              axisLabelStyle: axisLabelStyle,
            ),
          ),
        if (temps.isNotEmpty && hums.isNotEmpty) const SizedBox(height: 16),
        if (hums.isNotEmpty)
          _ChartSection(
            title: '湿度',
            icon: Icons.water_drop,
            color: AppTheme.accentHumidity,
            currentValue: '${hums.last.toStringAsFixed(1)}%',
            chart: _buildChart(
              context: context,
              values: hums,
              times: humTimes,
              timeMin: timeMin,
              timeSpan: timeSpan,
              color: AppTheme.accentHumidity,
              axisLabelStyle: axisLabelStyle,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Format a normalized X value (0..timeSpan) back to a time label.
  String _formatX(double normalizedX, double timeMin) {
    final ms = timeMin + normalizedX;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    switch (range) {
      case HistoryRange.day:
        return DateFormat('HH:mm').format(dt);
      case HistoryRange.week:
      case HistoryRange.month:
        return DateFormat('M/d').format(dt);
    }
  }

  Widget _buildChart({
    required BuildContext context,
    required List<double> values,
    required List<double> times,
    required double timeMin,
    required double timeSpan,
    required Color color,
    required TextStyle? axisLabelStyle,
  }) {
    final spots = List.generate(values.length, (i) {
      return FlSpot(
        times[i] - timeMin, // normalize to 0
        values[i],
      );
    });

    final xInterval = _niceXInterval(timeSpan);
    final minY = _computeMin(values);
    final maxY = _computeMax(values);
    final yInterval = _niceInterval(minY, maxY);
    final peakIndices = _findPeaks(values);
    final troughIndices = _findTroughs(values);
    final peaks = peakIndices.toSet();
    final troughs = troughIndices.toSet();

    // Determine which Y ticks to label — only the first and last.
    final firstYTick = (minY / yInterval).ceil() * yInterval;
    final lastYTick = (maxY / yInterval).floor() * yInterval;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          verticalInterval: xInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.gridLine(context),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: AppTheme.gridLine(context),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                // Only show first and last Y tick labels.
                if ((value - firstYTick).abs() > 0.001 &&
                    (value - lastYTick).abs() > 0.001) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toStringAsFixed(1),
                  style: axisLabelStyle,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatX(value, timeMin),
                  style: axisLabelStyle?.copyWith(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (peaks.contains(index)) {
                  return FlDotCirclePainter(
                    radius: 6,
                    strokeWidth: 3,
                    strokeColor: AppTheme.accentDanger,
                    color: AppTheme.bgPrimary(context),
                  );
                }
                if (troughs.contains(index)) {
                  return FlDotCirclePainter(
                    radius: 6,
                    strokeWidth: 3,
                    strokeColor: AppTheme.accentSuccess,
                    color: AppTheme.bgPrimary(context),
                  );
                }
                return FlDotCirclePainter(
                  radius: 2,
                  strokeWidth: 1,
                  color: color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.06),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.bgSecondary(context),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final value = values[index];
                final timeStr = _formatX(times[index] - timeMin, timeMin);
                String suffix = '';
                if (peaks.contains(index)) suffix = '  ↑ 峰值';
                if (troughs.contains(index)) suffix = '  ↓ 谷值';
                return LineTooltipItem(
                  '$timeStr\n${value.toStringAsFixed(2)}$suffix',
                  TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// Choose a nice X tick interval (in ms) so we get 4-6 labels.
  double _niceXInterval(double timeSpanMs) {
    if (timeSpanMs <= 0) return 1;

    if (range == HistoryRange.day) {
      if (timeSpanMs > 12 * 3600000) return 4 * 3600000; // 4h
      return 2 * 3600000; // 2h
    }
    if (range == HistoryRange.week) {
      return 86400000; // 1 day
    }
    return 5 * 86400000; // 5 days
  }

  List<int> _findPeaks(List<double> values) {
    if (values.length < 3) return [];
    final peaks = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (i == 0) {
        if (values.length > 1 && values[0] > values[1]) peaks.add(0);
      } else if (i == values.length - 1) {
        if (values[i] > values[i - 1]) peaks.add(i);
      } else {
        if (values[i] > values[i - 1] && values[i] > values[i + 1]) {
          peaks.add(i);
        }
      }
    }
    return peaks;
  }

  List<int> _findTroughs(List<double> values) {
    if (values.length < 3) return [];
    final troughs = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (i == 0) {
        if (values.length > 1 && values[0] < values[1]) troughs.add(0);
      } else if (i == values.length - 1) {
        if (values[i] < values[i - 1]) troughs.add(i);
      } else {
        if (values[i] < values[i - 1] && values[i] < values[i + 1]) {
          troughs.add(i);
        }
      }
    }
    return troughs;
  }

  double _computeMin(List<double> values) {
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);
    final range = mx - mn;
    final padding = range > 0 ? range * 0.1 : 1.0;
    return (mn - padding);
  }

  double _computeMax(List<double> values) {
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);
    final range = mx - mn;
    final padding = range > 0 ? range * 0.1 : 1.0;
    return (mx + padding);
  }

  double _niceInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 0) return 1;
    final raw = range / 5;
    final magnitude = _magnitude(raw);
    final normalized = raw / magnitude;
    if (normalized <= 0.15) return 0.1 * magnitude;
    if (normalized <= 0.35) return 0.2 * magnitude;
    if (normalized <= 0.75) return 0.5 * magnitude;
    if (normalized <= 1.5) return 1 * magnitude;
    if (normalized <= 3.5) return 2 * magnitude;
    if (normalized <= 7.5) return 5 * magnitude;
    return 10 * magnitude;
  }

  double _magnitude(double x) {
    return pow(10, (log(x) / ln10).floor()).toDouble();
  }
}

/// A compact chart section with title + current value + chart.
class _ChartSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String currentValue;
  final Widget chart;

  const _ChartSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.currentValue,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  currentValue,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 170,
            child: chart,
          ),
        ],
      ),
    );
  }
}
