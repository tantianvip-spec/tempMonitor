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
        );

    final times = readings.map((r) => r.recordedAt.millisecondsSinceEpoch.toDouble()).toList();
    final timeMin = times.reduce((a, b) => a < b ? a : b);
    final timeMax = times.reduce((a, b) => a > b ? a : b);
    final timeSpan = timeMax - timeMin;
    // Normalize X to [0, timeSpan] so fl_chart has manageable numbers.
    final temps = readings.map((r) => r.temperature).toList();
    final hums = readings.map((r) => r.humidity).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      children: [
        _ChartCard(
          title: '温度',
          color: AppTheme.accentTemp,
          icon: Icons.thermostat,
          chart: _buildChart(
            context: context,
            values: temps,
            times: times,
            timeMin: timeMin,
            timeSpan: timeSpan,
            color: AppTheme.accentTemp,
            axisLabelStyle: axisLabelStyle,
            unitLabel: '°C',
          ),
        ),
        const SizedBox(height: 24),
        _ChartCard(
          title: '湿度',
          color: AppTheme.accentHumidity,
          icon: Icons.water_drop,
          chart: _buildChart(
            context: context,
            values: hums,
            times: times,
            timeMin: timeMin,
            timeSpan: timeSpan,
            color: AppTheme.accentHumidity,
            axisLabelStyle: axisLabelStyle,
            unitLabel: '%',
          ),
        ),
        const SizedBox(height: 24),
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
    required String unitLabel,
  }) {
    final spots = List.generate(values.length, (i) {
      return FlSpot(
        times[i] - timeMin, // normalize to 0
        values[i],
      );
    });

    // Compute nice X tick interval
    final xInterval = _niceXInterval(timeSpan);

    final minY = _computeMin(values);
    final maxY = _computeMax(values);
    final yInterval = _niceInterval(minY, maxY);
    final peakIndices = _findPeaks(values);
    final troughIndices = _findTroughs(values);
    final peaks = peakIndices.toSet();
    final troughs = troughIndices.toSet();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yInterval,
          verticalInterval: xInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.gridLine(context),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: AppTheme.gridLine(context),
            strokeWidth: 1,
            dashArray: [4, 4],
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
            axisNameWidget: Text(unitLabel, style: axisLabelStyle),
            axisNameSize: 20,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: yInterval,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(2),
                style: axisLabelStyle,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              switch (range) {
                HistoryRange.day => '时间',
                HistoryRange.week || HistoryRange.month => '日期',
              },
              style: axisLabelStyle,
            ),
            axisNameSize: 20,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatX(value, timeMin),
                    style: axisLabelStyle?.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppTheme.border(context), width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (peaks.contains(index)) {
                  return FlDotCirclePainter(
                    radius: 5,
                    strokeWidth: 2,
                    strokeColor: AppTheme.accentDanger,
                    color: AppTheme.bgPrimary(context),
                  );
                }
                if (troughs.contains(index)) {
                  return FlDotCirclePainter(
                    radius: 5,
                    strokeWidth: 2,
                    strokeColor: AppTheme.accentSuccess,
                    color: AppTheme.bgPrimary(context),
                  );
                }
                return FlDotCirclePainter(
                  radius: 0,
                  strokeWidth: 0,
                  color: Colors.transparent,
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
                  '$timeStr\n${value.toStringAsFixed(2)}$unitLabel$suffix',
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
    // For 24h: show ~6 ticks (every 4 hours = 14,400,000 ms)
    // For 7d: show ~7 ticks (every 1 day = 86,400,000 ms)
    // For 30d: show ~6 ticks (every 5 days = 432,000,000 ms)
    if (timeSpanMs <= 0) return 1;

    if (range == HistoryRange.day) {
      // Target ~6 ticks → every 4 hours
      if (timeSpanMs > 12 * 3600000) return 4 * 3600000; // 4h
      return 2 * 3600000; // 2h
    }
    if (range == HistoryRange.week) {
      return 86400000; // 1 day
    }
    // month
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

class _ChartCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final Widget chart;

  const _ChartCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bgSecondary(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }
}
