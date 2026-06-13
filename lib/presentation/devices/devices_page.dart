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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
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

  void _startScan() {
    setState(() => _isScanning = true);
    context.read<ScanService>().forceRestart();
    context.read<ScanService>().scanNow();

    _nearbySubscription?.cancel();
    _nearbySubscription = context.read<ScanService>().nearbyDevices.listen((bundle) {
      if (!mounted) return;
      setState(() => _nearbyDevices = bundle.nearbyDevices);
      _clearTimer?.cancel();
      _clearTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        setState(() {
          _nearbyDevices = [];
          _isScanning = false;
        });
      });
    });
  }

  void _stopScan() {
    _nearbySubscription?.cancel();
    _nearbySubscription = null;
    _clearTimer?.cancel();
    _nearbyDevices = [];
    _isScanning = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SensorRepository>();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('设备列表'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.bluetooth()),
            tooltip: '扫描附近设备',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      drawer: _ScanDrawer(
        isScanning: _isScanning,
        nearbyDevices: _nearbyDevices,
        onStartScan: _startScan,
        onStopScan: _stopScan,
      ),
      body: StreamBuilder<List<Device>>(
        stream: repository.watchAllDevices(),
        builder: (context, snapshot) {
          final savedDevices = snapshot.data ?? const <Device>[];

          if (savedDevices.isEmpty) {
            return _EmptyState(
              scanService: context.read<ScanService>(),
              onScanTap: () => _scaffoldKey.currentState?.openDrawer(),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              ...savedDevices.map((device) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceCard(
                      device: device,
                      onTap: () =>
                          _openDashboard(context, repository, device),
                    ),
              )),
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

/// Drawer that shows nearby BLE devices after scanning.
class _ScanDrawer extends StatelessWidget {
  final bool isScanning;
  final List<NearbyDevice> nearbyDevices;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;

  const _ScanDrawer({
    required this.isScanning,
    required this.nearbyDevices,
    required this.onStartScan,
    required this.onStopScan,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.bluetoothConnected(),
                    color: isScanning
                        ? AppTheme.accentTemp
                        : AppTheme.textMuted,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '蓝牙扫描',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isScanning ? '正在扫描…' : '点击按钮开始扫描',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isScanning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentTemp,
                      ),
                    ),
                ],
              ),
            ),

            // Scan button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isScanning ? onStopScan : onStartScan,
                  icon: Icon(
                    isScanning ? Icons.stop : Icons.refresh,
                    size: 20,
                  ),
                  label: Text(isScanning ? '停止扫描' : '开始扫描'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isScanning
                        ? AppTheme.accentDanger.withOpacity(0.2)
                        : AppTheme.accentTemp.withOpacity(0.2),
                    foregroundColor: isScanning
                        ? AppTheme.accentDanger
                        : AppTheme.accentTemp,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

            // Divider
            if (nearbyDevices.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: AppTheme.border, height: 1),
              ),

            // Nearby device list
            if (nearbyDevices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '附近的设备 (${nearbyDevices.length})',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            Expanded(
              child: nearbyDevices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isScanning
                                  ? PhosphorIcons.wifiSlash()
                                  : PhosphorIcons.bluetoothSlash(),
                              size: 48,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isScanning
                                  ? '正在搜索蓝牙设备…'
                                  : '未扫描到设备',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: nearbyDevices.length,
                      itemBuilder: (context, index) {
                        final device = nearbyDevices[index];
                        return _NearbyDeviceTile(
                          device: device,
                          onTap: () {
                            if (device.isBThomeCompatible) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '选中 ${device.name ?? device.deviceId}',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('该设备不兼容 BThome 协议'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
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
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: device.isBThomeCompatible
              ? AppTheme.accentSuccess.withOpacity(0.15)
              : AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          device.isBThomeCompatible
              ? PhosphorIcons.thermometer()
              : PhosphorIcons.bluetoothSlash(),
          color: device.isBThomeCompatible
              ? AppTheme.accentSuccess
              : AppTheme.textMuted,
          size: 18,
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
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: device.isBThomeCompatible
                  ? AppTheme.accentSuccess.withOpacity(0.2)
                  : AppTheme.textMuted.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              device.isBThomeCompatible ? 'BThome' : '未知',
              style: TextStyle(
                fontSize: 9,
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
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
      trailing: device.isBThomeCompatible
          ? const Icon(Icons.add_circle_outline,
              color: AppTheme.accentSuccess, size: 18)
          : null,
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SensorRepository>();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: AppTheme.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.bgTertiary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  PhosphorIcons.thermometer(),
                  color: AppTheme.accentTemp,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Name + latest reading
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<Reading?>(
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
                        return Row(
                          children: [
                            const Icon(Icons.thermostat, size: 13, color: AppTheme.accentTemp),
                            const SizedBox(width: 3),
                            Text(
                              reading.temperature.toTempString(),
                              style: const TextStyle(
                                color: AppTheme.accentTemp,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.water_drop, size: 13, color: AppTheme.accentHumidity),
                            const SizedBox(width: 3),
                            Text(
                              reading.humidity.toHumidityString(),
                              style: const TextStyle(
                                color: AppTheme.accentHumidity,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Chevron
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ScanService scanService;
  final VoidCallback onScanTap;

  const _EmptyState({
    required this.scanService,
    required this.onScanTap,
  });

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
                  : '请添加蓝牙温湿度传感器',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            if (!mockMode) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onScanTap,
                icon: const Icon(Icons.bluetooth_searching, size: 18),
                label: const Text('扫描附近设备'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => scanService.restart(),
              child: const Text('重新启动扫描', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
