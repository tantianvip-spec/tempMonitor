import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:temp_monitor/core/extensions.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/device.dart';
import 'package:temp_monitor/domain/models/nearby_device.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/infrastructure/permission_service.dart';
import 'package:temp_monitor/infrastructure/ble_scanner.dart';
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
  StreamSubscription<ScanResultBundle>? _nearbySubscription;
  List<NearbyDevice> _nearbyDevices = [];
  bool _isScanning = false;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _listenToNearby();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-subscribe if needed after dependency change.
    _listenToNearby();
  }

  void _listenToNearby() {
    _nearbySubscription?.cancel();
    try {
      final scanService = context.read<ScanService>();
      _nearbySubscription = scanService.nearbyDevices.listen((bundle) {
        if (!mounted) return;
        setState(() {
          _nearbyDevices = bundle.nearbyDevices;
          _isScanning = true;
        });
        // Reset the clear timer: auto-clear 10s after the LAST update.
        _clearTimer?.cancel();
        _clearTimer = Timer(const Duration(seconds: 10), () {
          if (!mounted) return;
          setState(() {
            _nearbyDevices = [];
            _isScanning = false;
          });
        });
      });
    } catch (_) {
      // ScanService not available — likely in test context.
    }
  }

  @override
  void dispose() {
    _nearbySubscription?.cancel();
    _clearTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final bleGranted = await PermissionService.requestBlePermissions();
    final notifGranted =
        await PermissionService.requestNotificationPermission();
    if (!bleGranted || !notifGranted) {
      DebugLogger()
          .w('Some runtime permissions were denied', tag: 'DevicesPage');
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
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentTemp,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新扫描',
            onPressed: () {
              setState(() => _isScanning = true);
              context.read<ScanService>().forceRestart();
              context.read<ScanService>().scanNow();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('正在扫描附近的蓝牙设备…'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Device>>(
        stream: repository.watchAllDevices(),
        builder: (context, snapshot) {
          final savedDevices = snapshot.data ?? const <Device>[];

          // Show empty state only if nothing at all.
          if (savedDevices.isEmpty && _nearbyDevices.isEmpty) {
            if (_isScanning) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accentTemp),
                    SizedBox(height: 16),
                    Text(
                      '正在扫描…',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '请确保蓝牙已开启且设备在附近',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              );
            }
            return _EmptyState(scanService: context.read<ScanService>());
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Saved devices section
              if (savedDevices.isNotEmpty) ...[
                const _SectionHeader(title: '已配对的设备'),
                ...savedDevices.map((device) => _DeviceTile(
                      device: device,
                      onTap: () =>
                          _openDashboard(context, repository, device),
                    )),
              ],

              // Nearby devices section
              if (_nearbyDevices.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      const _SectionHeader(title: '附近的蓝牙设备'),
                      const Spacer(),
                      if (_isScanning)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentTemp,
                          ),
                        ),
                    ],
                  ),
                ),
                ..._nearbyDevices.map((device) => _NearbyDeviceTile(
                      device: device,
                      onTap: () {
                        // For BThome-compatible devices, navigate to dashboard.
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              device.isBThomeCompatible
                                  ? '正在连接 ${device.name ?? device.deviceId}…'
                                  : '该设备不兼容 BThome 协议',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    )),
              ],
            ],
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
    Stream<Reading>? readingStream;
    try {
      readingStream = Provider.of<Stream<Reading>>(context, listen: false);
    } catch (_) {}

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

class _NearbyDeviceTile extends StatelessWidget {
  final NearbyDevice device;
  final VoidCallback onTap;

  const _NearbyDeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: device.isBThomeCompatible
              ? AppTheme.accentSuccess.withOpacity(0.15)
              : AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          device.isBThomeCompatible
              ? PhosphorIcons.thermometer()
              : PhosphorIcons.bluetoothSlash(),
          color: device.isBThomeCompatible
              ? AppTheme.accentSuccess
              : AppTheme.textMuted,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              device.name ?? device.deviceId,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: device.isBThomeCompatible
                  ? AppTheme.accentSuccess.withOpacity(0.2)
                  : AppTheme.textMuted.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              device.isBThomeCompatible ? 'BThome' : '未知',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: device.isBThomeCompatible
                    ? AppTheme.accentSuccess
                    : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '信号: ${device.rssi} dBm',
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      trailing: device.isBThomeCompatible
          ? const Icon(Icons.add_circle_outline,
              color: AppTheme.accentSuccess, size: 22)
          : null,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
