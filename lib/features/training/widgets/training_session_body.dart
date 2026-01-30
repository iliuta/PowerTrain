import 'package:flutter/material.dart';
import '../../../core/config/live_data_display_config.dart';
import '../model/expanded_training_session_definition.dart';
import '../training_session_controller.dart';
import 'session_progress_bar.dart';
import 'training_interval_list.dart';
import 'live_ftms_data_widget.dart';

/// Body content for the training session screen
class TrainingSessionBody extends StatelessWidget {
  final ExpandedTrainingSessionDefinition session;
  final TrainingSessionController controller;
  final LiveDataDisplayConfig? config;

  const TrainingSessionBody({
    super.key,
    required this.session,
    required this.controller,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 0, right: 4, bottom: 4),
        child: Column(
          children: [
            SessionProgressBar(
              progress: session.isDistanceBased
                ? (controller.state.totalDistance > 0 ? controller.state.elapsedDistance / controller.state.totalDistance : 0.0)
                : (controller.state.totalDuration > 0 ? controller.state.elapsedSeconds / controller.state.totalDuration : 0.0),
              timeLeft: session.isDistanceBased ? controller.state.sessionDistanceLeft : controller.state.sessionTimeLeft,
              elapsed: session.isDistanceBased ? controller.state.elapsedDistance : controller.state.elapsedSeconds,
              formatTime: session.isDistanceBased ? _formatDistance : _formatTime,
              intervals: controller.state.intervals,
              machineType: session.ftmsMachineType,
              config: config,
              isDistanceBased: session.isDistanceBased,
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // Interval list
                        Expanded(
                          child: TrainingIntervalList(
                            intervals: controller.state.intervals,
                            currentInterval: controller.state.currentIntervalIndex,
                            intervalElapsed: session.isDistanceBased
                              ? controller.state.intervalElapsedDistance
                              : controller.state.intervalElapsedSeconds,
                            intervalTimeLeft: session.isDistanceBased
                              ? controller.state.intervalDistanceLeft
                              : controller.state.intervalTimeLeft,
                            formatMMSS: _formatMMSS,
                            formatDistance: _formatDistance,
                            config: config,
                            isDistanceBased: session.isDistanceBased,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: LiveFTMSDataWidget(
                      targets: controller.state.currentInterval.targets,
                      machineType: session.ftmsMachineType,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(num meters) {
    final double m = meters.toDouble();
    if (m >= 1000) {
      return '${(m / 1000).toStringAsFixed(1)}km';
    } else {
      return '${m.toStringAsFixed(0)}m';
    }
  }

  String _formatTime(num seconds) {
    int totalSeconds = seconds.toInt();
    int hours = totalSeconds ~/ 3600;
    int mins = (totalSeconds % 3600) ~/ 60;
    int secs = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _formatMMSS(num seconds) {
    int totalSeconds = seconds.toInt();
    int mins = totalSeconds ~/ 60;
    int secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
