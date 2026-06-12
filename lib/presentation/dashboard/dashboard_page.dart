import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/core/extensions.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/history/history_cubit.dart';
import 'package:temp_monitor/presentation/history/history_page.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/widgets/current_reading_card.dart';

class DashboardPage extends StatelessWidget {
  final String deviceId;

  const DashboardPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: '历史曲线',
            onPressed: () => _openHistory(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<DashboardCubit>().loadLatest(deviceId);
        },
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            if (state.status == DashboardStatus.loading &&
                state.latestReading == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final reading = state.latestReading;
            if (reading == null) {
              return ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('暂无数据，请确保设备在附近')),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CurrentReadingCard(
                  label: '温度',
                  value: reading.temperature.toTempString(),
                  icon: Icons.thermostat,
                  accent: AppTheme.accentTemp,
                ),
                const SizedBox(height: 12),
                CurrentReadingCard(
                  label: '湿度',
                  value: reading.humidity.toHumidityString(),
                  icon: Icons.water_drop,
                  accent: AppTheme.accentHumidity,
                ),
                if (reading.battery != null) ...[
                  const SizedBox(height: 12),
                  CurrentReadingCard(
                    label: '电量',
                    value: '${reading.battery}%',
                    icon: Icons.battery_full,
                    accent: AppTheme.accentSuccess,
                  ),
                ],
                if (reading.rssi != null) ...[
                  const SizedBox(height: 12),
                  CurrentReadingCard(
                    label: '信号',
                    value: '${reading.rssi} dBm',
                    icon: Icons.wifi_tethering,
                    accent: AppTheme.accentHumidity,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '更新时间: ${reading.recordedAt.toDisplayString()}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openHistory(BuildContext context) {
    final repository = context.read<SensorRepository>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) =>
              HistoryCubit(repository)..loadHistory(deviceId, HistoryRange.day),
          child: HistoryPage(deviceId: deviceId),
        ),
      ),
    );
  }
}
