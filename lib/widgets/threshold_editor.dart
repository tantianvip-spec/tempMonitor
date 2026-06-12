import 'package:flutter/material.dart';

/// Reusable dialog for editing a min/max range using two sliders.
///
/// Returns a `(double, double)` record `(min, max)` via `Navigator.pop`
/// when the user confirms, or `null` if cancelled.
class ThresholdEditorDialog extends StatefulWidget {
  final double min;
  final double max;
  final double sliderMin;
  final double sliderMax;
  final int divisions;
  final String title;
  final String unitLabel;

  const ThresholdEditorDialog({
    super.key,
    required this.min,
    required this.max,
    this.sliderMin = -40,
    this.sliderMax = 80,
    this.divisions = 120,
    this.title = '编辑阈值',
    this.unitLabel = '',
  });

  @override
  State<ThresholdEditorDialog> createState() => _ThresholdEditorDialogState();
}

class _ThresholdEditorDialogState extends State<ThresholdEditorDialog> {
  late double min;
  late double max;

  @override
  void initState() {
    super.initState();
    min = widget.min;
    max = widget.max;
  }

  @override
  Widget build(BuildContext context) {
    final suffix = widget.unitLabel.isEmpty ? '' : ' ${widget.unitLabel}';
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('下限: ${min.toStringAsFixed(1)}$suffix'),
          Slider(
            value: min,
            min: widget.sliderMin,
            max: widget.sliderMax,
            divisions: widget.divisions,
            label: min.toStringAsFixed(1),
            onChanged: (value) => setState(() {
              min = value;
              if (min > max) max = min;
            }),
          ),
          Text('上限: ${max.toStringAsFixed(1)}$suffix'),
          Slider(
            value: max,
            min: widget.sliderMin,
            max: widget.sliderMax,
            divisions: widget.divisions,
            label: max.toStringAsFixed(1),
            onChanged: (value) => setState(() {
              max = value;
              if (max < min) min = max;
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (min, max)),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
