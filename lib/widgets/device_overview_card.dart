import 'package:flutter/material.dart';
import 'package:temp_monitor/core/extensions.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/reading.dart';

/// Compact card showing one device's real-time readings.
///
/// Intended for use inside a PageView on the dashboard page.
/// Shows device name, temperature (large), humidity + battery,
/// and signal strength.
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
      child: Container(
        width: 160,
        height: 120,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device name
            Text(
              deviceName,
              style: textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Temperature — large
            Text(
              reading?.temperature.toTempString() ?? '--',
              style: textTheme.headlineMedium?.copyWith(
                color: AppTheme.accentTemp,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Humidity · Battery
            Text(
              reading != null
                  ? '${reading!.humidity.toHumidityString()} · ${reading!.battery ?? "--"}'
                  : '-- · --',
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 2),
            // Signal
            Text(
              reading?.rssi != null ? '${reading!.rssi} dBm' : '--',
              style: textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
