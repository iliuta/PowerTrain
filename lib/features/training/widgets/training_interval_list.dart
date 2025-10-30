
import 'package:flutter/material.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';

import '../../../core/config/live_data_display_config.dart';
import '../interval_target_fields_display.dart';

class TrainingIntervalList extends StatelessWidget {
  final List<ExpandedUnitTrainingInterval> intervals;
  final int currentInterval;
  final int intervalElapsed;
  final int intervalTimeLeft;
  final String Function(int) formatMMSS;
  final LiveDataDisplayConfig? config;

  const TrainingIntervalList({
    super.key,
    required this.intervals,
    required this.currentInterval,
    required this.intervalElapsed,
    required this.intervalTimeLeft,
    required this.formatMMSS,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    final remainingIntervals = intervals.sublist(currentInterval);
    return ListView.builder(
      itemCount: remainingIntervals.length,
      itemBuilder: (context, idx) {
        final ExpandedUnitTrainingInterval interval = remainingIntervals[idx];
        final isCurrent = idx == 0;
        final intervalProgress = isCurrent ? intervalElapsed / interval.duration : 0.0;
        return Card(
          color: isCurrent ? Colors.blue[50] : null,
          child: ListTile(
            title: Text(
              _intervalTitleWithIndex(
                interval.title ?? 'Interval',
                currentInterval + idx + 1,
                intervals.length,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isCurrent)
                      Text(
                        formatMMSS(intervalElapsed),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    if (isCurrent) const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: intervalProgress,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCurrent)
                      Text(
                        formatMMSS(intervalTimeLeft),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    else
                      Text(formatMMSS(interval.duration)),
                  ],
                ),
                IntervalTargetFieldsDisplay(
                  targets: interval.targets,
                  config: config,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Returns the interval title with its index and total, e.g. "Warmup (3/5)"
String _intervalTitleWithIndex(String title, int index, int total) {
  return '$title ($index/$total)';
}
