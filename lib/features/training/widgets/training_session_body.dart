import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
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
  final BluetoothDevice ftmsDevice;

  const TrainingSessionBody({
    super.key,
    required this.session,
    required this.controller,
    this.config,
    required this.ftmsDevice,
  });

  @override
  Widget build(BuildContext context) {
    final isDistanceBased = session.isDistanceBased;
    final progress = isDistanceBased 
        ? controller.state.elapsedDistance / controller.state.totalDistance
        : controller.state.elapsedSeconds / controller.state.totalDuration;
    final timeLeft = isDistanceBased 
        ? controller.state.sessionDistanceLeft 
        : controller.state.sessionTimeLeft;
    final elapsed = isDistanceBased 
        ? controller.state.elapsedDistance 
        : controller.state.elapsedSeconds;
    final formatTime = isDistanceBased ? _formatDistance : _formatTime;
    final intervalElapsed = isDistanceBased 
        ? controller.state.intervalElapsedDistance 
        : controller.state.intervalElapsedSeconds;
    final intervalTimeLeft = isDistanceBased 
        ? controller.state.intervalDistanceLeft 
        : controller.state.intervalTimeLeft;
    final formatMMSS = isDistanceBased ? _formatDistanceMM : _formatMMSS;

    return SafeArea(
      bottom: false,
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SessionProgressBar(
            progress: progress,
            timeLeft: timeLeft,
            elapsed: elapsed,
            formatTime: formatTime,
            intervals: controller.state.intervals,
            machineType: session.ftmsMachineType,
            config: config,
            isDistanceBased: isDistanceBased,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TrainingIntervalList(
                    intervals: controller.state.intervals,
                    currentInterval: controller.state.currentIntervalIndex,
                    intervalElapsed: intervalElapsed,
                    intervalTimeLeft: intervalTimeLeft,
                    formatMMSS: formatMMSS,
                    config: config,
                    isDistanceBased: isDistanceBased,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: LiveFTMSDataWidget(
                    ftmsDevice: ftmsDevice,
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

  String _formatTime(num value) {
    final seconds = value.toInt();
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatMMSS(num value) {
    final seconds = value.toInt();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDistance(num meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    } else {
      return '${meters.toStringAsFixed(0)}m';
    }
  }

  String _formatDistanceMM(num meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    } else {
      return '${meters.toStringAsFixed(0)}m';
    }
  }
}
