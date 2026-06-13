import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:temp_monitor/core/extensions.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/permission_service.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_cubit.dart';
import 'package:temp_monitor/presentation/dashboard/dashboard_page.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/scan_service.dart';
import 'package:temp_monitor/services/settings_service.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final bleGranted = await PermissionService.requestBlePermissions();
    final notifGranted = await PermissionService.requestNotificationPermission();
    if (!bleGranted || !notifGranted) {
      DebugLogger().w('Some runtime permissions were denied', tag: 'DevicesPage');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SensorRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备列表'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.bluetoothConnected()),
            tooltip: '重新扫描',
            onPressed: () {
              context.read<ScanService>().restart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已触发重新扫描'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
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
            return _EmptyState(scanService: context.read<ScanService>());
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
    // readingStream is an optional provider registered only when the
    // background isolate is active. Use a try-get pattern so the
    // devices page works even in test contexts that don't provide one.
    Stream<Reading>? readingStream;
    try {
      readingStream = Provider.of<Stream<Reading>>(context, listen: false);
    } catch (_) {
      // not registered — skip real-time wiring.
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => DashboardCubit(
            repository,
            readingStream: readingStream,
          )..loadLatest(device.id),
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
    final repository = context.read<SensorRepository>();

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
      subtitle: FutureBuilder<Reading?>(
        future: repository.getLatestReading(device.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text(
              '加载中…',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            );
          }
          final reading = snapshot.data;
          if (reading == null) {
            return const Text(
              '暂无数据',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            );
          }
          final ago = reading.recordedAt.toAgoString();
          return Text(
            '$ago · ${reading.temperature.toTempString()} · ${reading.humidity.toHumidityString()}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          );
        },
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textMuted,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ScanService scanService;

  const _EmptyState({required this.scanService});

  @override
  Widget build(BuildContext context) {
    final mockMode = context.read<SettingsService>().getMockDeviceEnabled();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mockMode
                  ? PhosphorIcons.wrench()
                  : PhosphorIcons.bluetoothConnected(),
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              mockMode ? '模拟设备模式已开启' : '未发现设备',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mockMode
                  ? '等待模拟数据生成中…\n如果长时间无数据，请检查"设置"页面'
                  : '请确保设备在附近并已开启蓝牙\n或去"设置"中开启"模拟设备模式"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                scanService.restart();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已重新启动扫描'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新扫描'),
            ),
          ],
        ),
      ),
    );
  }
}
