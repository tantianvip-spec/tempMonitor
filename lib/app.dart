import 'package:flutter/material.dart';

class TempMonitorApp extends StatelessWidget {
  const TempMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '温湿度监控',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Temp Monitor')),
      ),
    );
  }
}
