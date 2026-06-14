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
  final Set<int> _selectedIndices = {};
  bool get _hasSelection => _selectedIndices.isNotEmpty;

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

  void _toggleSelection(int reversedIndex) {
    setState(() {
      if (_selectedIndices.contains(reversedIndex)) {
        _selectedIndices.remove(reversedIndex);
      } else {
        _selectedIndices.add(reversedIndex);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIndices.clear());

  void _copySelected(List<LogEntry> entries) {
    final selected = _selectedIndices.map((i) => entries[i].toLogLine());
    Clipboard.setData(ClipboardData(text: selected.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${_selectedIndices.length} 条日志')),
    );
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hasSelection ? '已选择 ${_selectedIndices.length} 条' : '调试日志'),
        centerTitle: true,
        actions: [
          if (_hasSelection) ...[
            IconButton(
              tooltip: '复制选中',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () {
                final state = context.read<DebugLogCubit>().state;
                _copySelected(state.entries);
              },
            ),
            IconButton(
              tooltip: '取消选择',
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
            ),
          ] else ...[
            IconButton(
              tooltip: '复制全部',
              icon: const Icon(Icons.copy_all_outlined),
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
            padding: EdgeInsets.zero,
            itemCount: state.entries.length,
            itemBuilder: (context, index) {
              // Reverse index: list is displayed newest-first, but we
              // store selection keys as the raw (oldest-first) index.
              final reversedIndex = state.entries.length - 1 - index;
              final entry = state.entries[reversedIndex];
              final isSelected = _selectedIndices.contains(reversedIndex);
              return _LogEntryTile(
                entry: entry,
                isSelected: isSelected,
                onLongPress: () => _toggleSelection(reversedIndex),
                onTap: _hasSelection ? () => _toggleSelection(reversedIndex) : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  const _LogEntryTile({
    required this.entry,
    this.isSelected = false,
    required this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: AppTheme.accentTemp.withOpacity(0.1),
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
      onLongPress: onLongPress,
      onTap: onTap,
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
