import 'package:flutter/material.dart';
import 'package:temp_monitor/core/theme.dart';

class TempMonitorApp extends StatelessWidget {
  const TempMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '温湿度监控',
      theme: AppTheme.darkTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.dark,
      home: const Scaffold(
        body: Center(child: Text('Temp Monitor')),
      ),
    );
  }
}
