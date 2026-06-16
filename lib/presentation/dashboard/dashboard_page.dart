import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/history/history_enums.dart';
import 'package:temp_monitor/widgets/device_overview_card.dart';
import 'package:temp_monitor/widgets/history_chart.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state.devices.isEmpty) {
            return _buildEmptyState(context);
          }

          final currentDevice = state.devices[state.currentDeviceIndex];

          return RefreshIndicator(
            onRefresh: () async {
              context.read<DashboardCubit>().switchToDevice(
                state.currentDeviceIndex,
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full-width PageView for device cards
                  SizedBox(
                    height: 120,
                    child: PageView.builder(
                      controller: PageController(viewportFraction: 1.0),
                      itemCount: state.devices.length,
                      onPageChanged: (index) {
                        context.read<DashboardCubit>().switchToDevice(index);
                      },
                      itemBuilder: (context, index) {
                        final device = state.devices[index];
                        final reading = index == state.currentDeviceIndex
                            ? state.latestReading
                            : null;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: DeviceOverviewCard(
                            deviceName: device.name,
                            reading: reading,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Page indicator dots
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(state.devices.length, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == state.currentDeviceIndex ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == state.currentDeviceIndex
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // History chart for current device
                  Text(
                    '${currentDevice.name} 的历史曲线',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),

                  if (state.historyStatus == HistoryStatus.loading &&
                      state.historyReadings.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.historyReadings.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: Text('暂无历史数据')),
                    )
                  else
                    HistoryChart(
                      readings: state.historyReadings,
                      range: state.range,
                      embedded: true,
                    ),

                  const SizedBox(height: 12),

                  // Time range selector
                  Center(
                    child: SegmentedButton<HistoryRange>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(
                            value: HistoryRange.day, label: Text('24h')),
                        ButtonSegment(
                            value: HistoryRange.week, label: Text('7d')),
                        ButtonSegment(
                            value: HistoryRange.month, label: Text('30d')),
                      ],
                      selected: {state.range},
                      onSelectionChanged: (selected) {
                        context
                            .read<DashboardCubit>()
                            .changeHistoryRange(selected.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.thermometer(),
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '请添加设备',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '前往「设备」标签页添加温湿度传感器',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
