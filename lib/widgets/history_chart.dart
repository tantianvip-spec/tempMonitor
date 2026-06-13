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

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      children: [
        _ChartCard(
          title: '温度',
          unit: '°C',
          color: AppTheme.accentTemp,
          icon: Icons.thermostat,
          chart: LineChart(
            LineChartData(
              minY: _computeTempMin(readings),
              maxY: _computeTempMax(readings),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppTheme.gridLine,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
                getDrawingVerticalLine: (_) => const FlLine(
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
                  axisNameWidget: Text('°C', style: axisLabelStyle),
                  axisNameSize: 20,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: axisLabelStyle,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: axisLabelStyle,
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: readings.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.temperature);
                  }).toList(),
                  isCurved: false,
                  color: AppTheme.accentTemp,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _ChartCard(
          title: '湿度',
          unit: '%',
          color: AppTheme.accentHumidity,
          icon: Icons.water_drop,
          chart: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppTheme.gridLine,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
                getDrawingVerticalLine: (_) => const FlLine(
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
                  axisNameWidget: Text('%', style: axisLabelStyle),
                  axisNameSize: 20,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: axisLabelStyle,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: axisLabelStyle,
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: readings.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.humidity);
                  }).toList(),
                  isCurved: false,
                  color: AppTheme.accentHumidity,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  double _computeTempMin(List<Reading> readings) {
    final min =
        readings.map((r) => r.temperature).reduce((a, b) => a < b ? a : b);
    return (min - 2).floorToDouble();
  }

  double _computeTempMax(List<Reading> readings) {
    final max =
        readings.map((r) => r.temperature).reduce((a, b) => a > b ? a : b);
    return (max + 2).ceilToDouble();
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final Color color;
  final IconData icon;
  final Widget chart;

  const _ChartCard({
    required this.title,
    required this.unit,
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
              height: 180,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }
}
