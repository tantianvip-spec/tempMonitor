import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/presentation/settings/settings_cubit.dart';
import 'package:temp_monitor/widgets/threshold_editor.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              const _SectionHeader(title: '扫描与存储'),
              ListTile(
                title: const Text('扫描频率'),
                subtitle: Text('${state.scanIntervalSeconds} 秒'),
                trailing: DropdownButton<int>(
                  value: state.scanIntervalSeconds,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 秒')),
                    DropdownMenuItem(value: 30, child: Text('30 秒')),
                    DropdownMenuItem(value: 60, child: Text('1 分钟')),
                    DropdownMenuItem(value: 300, child: Text('5 分钟（推荐）')),
                    DropdownMenuItem(value: 600, child: Text('10 分钟')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().setScanInterval(value);
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('数据保留天数'),
                subtitle: Text('${state.retentionDays} 天'),
                trailing: DropdownButton<int>(
                  value: state.retentionDays,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 天')),
                    DropdownMenuItem(value: 30, child: Text('30 天')),
                    DropdownMenuItem(value: 90, child: Text('90 天')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().setRetentionDays(value);
                    }
                  },
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              const _SectionHeader(title: '阈值告警'),
              _buildRangeTile(
                context,
                title: '温度阈值',
                subtitle:
                    '下限: ${state.tempMin.toStringAsFixed(1)}°C  上限: ${state.tempMax.toStringAsFixed(1)}°C',
                valueColor: AppTheme.accentTemp,
                onTap: () async {
                  final cubit = context.read<SettingsCubit>();
                  final result = await showDialog<(double, double)>(
                    context: context,
                    builder: (_) => ThresholdEditorDialog(
                      min: state.tempMin,
                      max: state.tempMax,
                      title: '温度阈值',
                      unitLabel: '°C',
                    ),
                  );
                  if (result != null) {
                    cubit.setTempRange(result.$1, result.$2);
                  }
                },
              ),
              _buildRangeTile(
                context,
                title: '湿度阈值',
                subtitle:
                    '下限: ${state.humidityMin.toStringAsFixed(1)}%  上限: ${state.humidityMax.toStringAsFixed(1)}%',
                valueColor: AppTheme.accentHumidity,
                onTap: () async {
                  final cubit = context.read<SettingsCubit>();
                  final result = await showDialog<(double, double)>(
                    context: context,
                    builder: (_) => ThresholdEditorDialog(
                      min: state.humidityMin,
                      max: state.humidityMax,
                      sliderMin: 0,
                      sliderMax: 100,
                      divisions: 100,
                      title: '湿度阈值',
                      unitLabel: '%',
                    ),
                  );
                  if (result != null) {
                    cubit.setHumidityRange(result.$1, result.$2);
                  }
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              const _SectionHeader(title: '外观'),
              ListTile(
                title: const Text('主题'),
                subtitle: Text(_themeLabel(state.themeMode)),
                trailing: DropdownButton<ThemeMode>(
                  value: state.themeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text('跟随系统')),
                    DropdownMenuItem(
                        value: ThemeMode.light, child: Text('浅色')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().setThemeMode(value);
                    }
                  },
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              const _SectionHeader(title: '开发'),
              SwitchListTile(
                title: const Text('模拟设备模式'),
                subtitle: const Text('不扫描真实蓝牙，生成假数据用于测试'),
                value: state.mockDeviceEnabled,
                activeColor: AppTheme.accentSuccess,
                onChanged: (value) =>
                    context.read<SettingsCubit>().setMockDeviceEnabled(value),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRangeTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color valueColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: valueColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.edit_outlined, color: valueColor, size: 18),
      ),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMuted(context),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

String _themeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
}