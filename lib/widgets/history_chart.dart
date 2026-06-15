import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/presentation/history/history_enums.dart';

class HistoryChart extends StatelessWidget {
  final List<Reading> readings;
  final HistoryRange range;
  final bool embedded;

  const HistoryChart({
    super.key,
    required this.readings,
    required this.range,
    this.embedded = false,
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

    final chartContent = Column(
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

    if (embedded) return chartContent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      children: [chartContent],
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

    final minY = _computeMin(values);
    final maxY = _computeMax(values);

    // Add small X padding so the first/last spots don't sit flush against
    // the chart edge.
    final xPad = timeSpan > 0 ? timeSpan * 0.02 : 1.0;

    return LineChart(
      LineChartData(
        minX: 0 - xPad,
        maxX: timeSpan + xPad,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          show: true,
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
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
                final unit = color == AppTheme.accentTemp ? '°C' : '%';
                return LineTooltipItem(
                  '$timeStr\n${value.toStringAsFixed(1)}$unit',
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

  double _computeMin(List<double> values) {
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);
    final range = mx - mn;
    // Ensure generous padding even when all values are nearly identical,
    // so tiny sensor noise (e.g. 25.04 vs 25.05) doesn't create a
    // visually steep slope. Minimum padding: 0.5°C / 5% humidity.
    final padding = range > 0.5 ? range * 0.15 : 0.5;
    return (mn - padding);
  }

  double _computeMax(List<double> values) {
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);
    final range = mx - mn;
    final padding = range > 0.5 ? range * 0.15 : 0.5;
    return (mx + padding);
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
