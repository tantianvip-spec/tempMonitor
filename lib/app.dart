import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/domain/models/reading.dart';
import 'package:temp_monitor/infrastructure/notification_service.dart';
import 'package:temp_monitor/presentation/debug/debug_log_cubit.dart';
import 'package:temp_monitor/presentation/debug/debug_log_page.dart';
import 'package:temp_monitor/presentation/devices/devices_page.dart';
import 'package:temp_monitor/presentation/settings/settings_cubit.dart';
import 'package:temp_monitor/presentation/settings/settings_page.dart';
import 'package:temp_monitor/repositories/sensor_repository.dart';
import 'package:temp_monitor/services/scan_service.dart';
import 'package:temp_monitor/services/settings_service.dart';

class TempMonitorApp extends StatelessWidget {
  final SensorRepository repository;
  final SettingsService settings;
  final NotificationService notifications;
  final Stream<Reading>? readingStream;
  final ScanService scanService;

  const TempMonitorApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.notifications,
    required this.scanService,
    this.readingStream,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: repository),
        RepositoryProvider.value(value: settings),
        RepositoryProvider.value(value: notifications),
        RepositoryProvider.value(value: scanService),
        if (readingStream != null)
          Provider<Stream<Reading>>.value(value: readingStream!),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit(settings, scanService)),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            return MaterialApp(
              title: '温湿度监控',
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: state.themeMode,
              home: const MainNavigationScreen(),
            );
          },
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DevicesPage(),
      const SettingsPage(),
      BlocProvider(
        create: (_) => DebugLogCubit(),
        child: const DebugLogPage(),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: '设备'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
          NavigationDestination(icon: Icon(Icons.bug_report), label: '调试'),
        ],
      ),
    );
  }
}