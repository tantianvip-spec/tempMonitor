import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SensorRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备列表'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Device>>(
        stream: repository.watchAllDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final devices = snapshot.data ?? const <Device>[];
          if (devices.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: devices.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 64, endIndent: 16),
            itemBuilder: (context, index) {
              final device = devices[index];
              return _DeviceTile(
                device: device,
                onTap: () => _openDashboard(context, repository, device),
              );
            },
          );
        },
      ),
    );
  }

  void _openDashboard(
    BuildContext context,
    SensorRepository repository,
    Device device,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) =>
              DashboardCubit(repository)..loadLatest(device.id),
          child: DashboardPage(deviceId: device.id),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const _DeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          PhosphorIcons.thermometer(),
          color: AppTheme.accentTemp,
          size: 22,
        ),
      ),
      title: Text(
        device.name,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      // TODO(task-17): show last reading in subtitle (e.g. "5秒前 · 25.3°C · 62.0%")
      subtitle: const Text(
        '—',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textMuted,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.thermometer(),
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              '未发现设备',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请确保设备在附近并已开启蓝牙',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
