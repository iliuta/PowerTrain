import 'package:flutter/material.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'training_session_chart.dart';

class SessionProgressBar extends StatelessWidget {
  final double progress;
  final int timeLeft;
  final int elapsed;
  final String Function(int) formatTime;
  final List<ExpandedUnitTrainingInterval> intervals;
  final DeviceType machineType;
  final LiveDataDisplayConfig? config;
  
  const SessionProgressBar({
    super.key,
    required this.progress,
    required this.timeLeft,
    required this.elapsed,
    required this.formatTime,
    required this.intervals,
    required this.machineType,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left time label (elapsed)
        SizedBox(
          width: 70,
          child: Text(
            formatTime(elapsed),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        // Training session chart with progress indicator
        Expanded(
          child: TrainingSessionChart(
            intervals: intervals,
            machineType: machineType,
            height: 60,
            config: config,
            currentProgress: progress,
          ),
        ),
        const SizedBox(width: 12),
        // Right time label (remaining)
        SizedBox(
          width: 70,
          child: Text(
            formatTime(timeLeft),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
