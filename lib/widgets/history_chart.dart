import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/reading.dart';

class HistoryChart extends StatelessWidget {
  final List<Reading> readings;

  const HistoryChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text('无历史数据'));
    }

    final axisLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted,
        );

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
            values: temps,
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
            values: hums,
            color: AppTheme.accentHumidity,
            axisLabelStyle: axisLabelStyle,
            unitLabel: '%',
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChart({
    required List<double> values,
    required Color color,
    required TextStyle? axisLabelStyle,
    required String unitLabel,
  }) {
    final spots = values.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    final minY = _computeMin(values);
    final maxY = _computeMax(values);
    final interval = _niceInterval(minY, maxY);
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
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppTheme.gridLine,
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
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(2),
                style: axisLabelStyle,
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppTheme.border, width: 1),
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
                    color: AppTheme.bgPrimary,
                  );
                }
                if (troughs.contains(index)) {
                  return FlDotCirclePainter(
                    radius: 5,
                    strokeWidth: 2,
                    strokeColor: AppTheme.accentSuccess,
                    color: AppTheme.bgPrimary,
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
            getTooltipColor: (_) => AppTheme.bgSecondary,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final value = values[index];
                String suffix = '';
                if (peaks.contains(index)) suffix = '  ↑ 峰值';
                if (troughs.contains(index)) suffix = '  ↓ 谷值';
                return LineTooltipItem(
                  '${value.toStringAsFixed(2)}$unitLabel$suffix',
                  TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// Find indices of local peaks (strictly higher than both neighbors).
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

  /// Find indices of local troughs (strictly lower than both neighbors).
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

  /// Adaptive Y-axis min with 10% padding below the lowest value.
  double _computeMin(List<double> values) {
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);
    final range = mx - mn;
    final padding = range > 0 ? range * 0.1 : 1.0;
    return (mn - padding);
  }

  /// Adaptive Y-axis max with 10% padding above the highest value.
  double _computeMax(List<double> values) {
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);
    final range = mx - mn;
    final padding = range > 0 ? range * 0.1 : 1.0;
    return (mx + padding);
  }

  /// Compute a "nice" tick interval that produces readable Y-axis labels.
  double _niceInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 0) return 1;
    // Target ~5 ticks
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

  /// Order of magnitude (e.g., 0.01 for 0.035, 1 for 5, 10 for 80).
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
      color: AppTheme.bgSecondary,
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
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
