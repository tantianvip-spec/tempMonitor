import 'package:flutter/material.dart';
import 'package:temp_monitor/core/theme.dart';

class CurrentReadingCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const CurrentReadingCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: accent),
                const SizedBox(width: 12),
                Text(
                  label.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: textTheme.displayMedium?.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
