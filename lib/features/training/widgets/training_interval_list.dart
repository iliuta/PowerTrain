
import 'package:flutter/material.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/l10n/app_localizations.dart';

import '../../../core/config/live_data_display_config.dart';
import 'interval_target_fields_display.dart';

class TrainingIntervalList extends StatelessWidget {
  final List<ExpandedUnitTrainingInterval> intervals;
  final int currentInterval;
  final num intervalElapsed;
  final num intervalTimeLeft;
  final String Function(num) formatMMSS;
  final String Function(double)? formatDistance;
  final LiveDataDisplayConfig? config;
  final bool isDistanceBased;

  const TrainingIntervalList({
    super.key,
    required this.intervals,
    required this.currentInterval,
    required this.intervalElapsed,
    required this.intervalTimeLeft,
    required this.formatMMSS,
    this.formatDistance,
    this.config,
    this.isDistanceBased = false,
  });

  @override
  Widget build(BuildContext context) {
    final remainingIntervals = intervals.sublist(currentInterval);
    final totalIntervalValue = isDistanceBased 
      ? (remainingIntervals.isNotEmpty ? (remainingIntervals[0].distance ?? 0) : 0) 
      : (remainingIntervals.isNotEmpty ? (remainingIntervals[0].duration ?? 0) : 0);
    final currentIntervalProgress = totalIntervalValue > 0 ? intervalElapsed / totalIntervalValue : 0.0;
    
    return Column(
      children: [
        // Global progress bar for current interval
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Row(
            children: [
              Text(
                isDistanceBased 
                  ? (formatDistance?.call(intervalElapsed.toDouble()) ?? intervalElapsed.toString())
                  : formatMMSS(intervalElapsed),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: currentIntervalProgress,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isDistanceBased 
                  ? (formatDistance?.call(intervalTimeLeft.toDouble()) ?? intervalTimeLeft.toString())
                  : formatMMSS(intervalTimeLeft),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: remainingIntervals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 2),
            itemBuilder: (context, idx) {
              final ExpandedUnitTrainingInterval interval = remainingIntervals[idx];
              final isCurrent = idx == 0;
              final intervalTotalValue = isDistanceBased ? (interval.distance ?? 0) : (interval.duration ?? 0);
              
              return Card(
                color: isCurrent ? Colors.blue[50] : null,
                margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and duration/distance on same line
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              interval.title == 'Workout' ? AppLocalizations.of(context)!.workout : (interval.title ?? AppLocalizations.of(context)!.interval),
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${currentInterval + idx + 1}/${intervals.length})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isCurrent
                              ? (isDistanceBased 
                                ? (formatDistance?.call(intervalTimeLeft.toDouble()) ?? intervalTimeLeft.toString())
                                : formatMMSS(intervalTimeLeft))
                              : (isDistanceBased 
                                ? (formatDistance?.call(intervalTotalValue.toDouble()) ?? intervalTotalValue.toString())
                                : formatMMSS(intervalTotalValue)),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Targets wrapped on same line with overflow
                      IntervalTargetFieldsDisplay(
                        targets: interval.targets,
                        config: config,
                        isInline: true,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
