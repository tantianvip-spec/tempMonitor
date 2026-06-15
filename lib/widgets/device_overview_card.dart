import 'package:flutter/material.dart';
import 'package:temp_monitor/core/extensions.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/reading.dart';

/// Full-width card showing one device's real-time readings.
///
/// Intended for use inside a PageView on the dashboard page.
/// Temperature is displayed large on the left; humidity, battery,
/// and signal are stacked on the right.
class DeviceOverviewCard extends StatelessWidget {
  final String deviceName;
  final Reading? reading;

  const DeviceOverviewCard({
    super.key,
    required this.deviceName,
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Left: device name (top) + temperature (large)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    deviceName,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reading?.temperature.toTempString() ?? '--°C',
                    style: textTheme.displayMedium?.copyWith(
                      color: AppTheme.accentTemp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Right: humidity · battery · signal
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dataRow(
                  context,
                  label: '湿度',
                  value: reading?.humidity.toHumidityString() ?? '--%',
                ),
                const SizedBox(height: 6),
                _dataRow(
                  context,
                  label: '电池',
                  value: reading?.battery?.toString() ?? '--',
                ),
                const SizedBox(height: 6),
                _dataRow(
                  context,
                  label: '信号',
                  value: reading?.rssi != null ? '${reading!.rssi} dBm' : '--',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataRow(BuildContext context, {
    required String label,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted(context),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
      ],
    );
  }
}
