import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp_monitor/core/theme.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';
import 'package:temp_monitor/presentation/debug/debug_log_cubit.dart';

class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh the log display every 2 seconds.
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        context.read<DebugLogCubit>().refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

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
            return Center(
              child: Text(
                '暂无日志',
                style: TextStyle(color: AppTheme.textMuted(context)),
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
            color: _colorForLevel(entry.level, context),
            shape: BoxShape.circle,
          ),
        ),
      ),
      title: Text(
        '[${entry.tag}] ${entry.message}',
        style: TextStyle(
          color: AppTheme.textPrimary(context),
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        entry.timestamp.toIso8601String(),
        style: TextStyle(
          color: AppTheme.textMuted(context),
          fontSize: 11,
        ),
      ),
    );
  }

  Color _colorForLevel(LogLevel level, BuildContext context) {
    return switch (level) {
      LogLevel.error => AppTheme.accentDanger,
      LogLevel.warning => AppTheme.accentWarning,
      LogLevel.info => AppTheme.accentHumidity,
      LogLevel.debug => AppTheme.textMuted(context),
      LogLevel.verbose => AppTheme.textMuted(context).withOpacity(0.5),
    };
  }
}
