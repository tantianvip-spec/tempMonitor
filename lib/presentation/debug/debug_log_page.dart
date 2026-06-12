import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/presentation/debug/debug_log_cubit.dart';

class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试日志'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              final text = context.read<DebugLogCubit>().export();
              Clipboard.setData(ClipboardData(text: text));
              messenger.showSnackBar(
                const SnackBar(content: Text('日志已复制到剪贴板')),
              );
            },
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.read<DebugLogCubit>().clear(),
          ),
        ],
      ),
      body: BlocBuilder<DebugLogCubit, DebugLogState>(
        builder: (context, state) {
          if (state.entries.isEmpty) {
            return const Center(
              child: Text(
                '暂无日志',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            );
          }
          return ListView.builder(
            reverse: true,
            itemCount: state.entries.length,
            itemBuilder: (context, index) {
              final entry = state.entries[state.entries.length - 1 - index];
              return _LogEntryTile(entry: entry);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.bgTertiary,
        foregroundColor: AppTheme.textPrimary,
        onPressed: () => context.read<DebugLogCubit>().refresh(),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _colorForLevel(entry.level),
            shape: BoxShape.circle,
          ),
        ),
      ),
      title: Text(
        '[${entry.tag}] ${entry.message}',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        entry.timestamp.toIso8601String(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
        ),
      ),
    );
  }

  static Color _colorForLevel(LogLevel level) {
    return switch (level) {
      LogLevel.error => AppTheme.accentDanger,
      LogLevel.warning => AppTheme.accentWarning,
      LogLevel.info => AppTheme.accentHumidity,
      LogLevel.debug => AppTheme.textMuted,
      LogLevel.verbose => AppTheme.textMuted.withOpacity(0.5),
    };
  }
}
