import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/presentation/history/history_cubit.dart';
import 'package:temp_monitor/presentation/history/history_enums.dart';
import 'package:temp_monitor/widgets/history_chart.dart';

class HistoryPage extends StatelessWidget {
  final String deviceId;

  const HistoryPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史曲线')),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<HistoryCubit, HistoryState>(
              builder: (context, state) {
                if (state.status == HistoryStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.readings.isEmpty) {
                  return const Center(child: Text('暂无历史数据'));
                }
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: HistoryChart(readings: state.readings, range: state.range),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: _buildRangeSelector(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    final cubit = context.read<HistoryCubit>();
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        return SegmentedButton<HistoryRange>(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: const [
            ButtonSegment(value: HistoryRange.day, label: Text('24h')),
            ButtonSegment(value: HistoryRange.week, label: Text('7d')),
            ButtonSegment(value: HistoryRange.month, label: Text('30d')),
          ],
          selected: {state.range},
          onSelectionChanged: (selected) {
            final range = selected.first;
            cubit.loadHistory(deviceId, range);
          },
        );
      },
    );
  }
}
