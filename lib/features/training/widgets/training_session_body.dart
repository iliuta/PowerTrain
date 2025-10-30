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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SessionProgressBar(
            progress: controller.elapsed / controller.totalDuration,
            timeLeft: controller.mainTimeLeft,
            elapsed: controller.elapsed,
            formatTime: _formatTime,
            intervals: controller.intervals,
            machineType: session.ftmsMachineType,
            config: config,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TrainingIntervalList(
                    intervals: controller.intervals,
                    currentInterval: controller.currentInterval,
                    intervalElapsed: controller.intervalElapsed,
                    intervalTimeLeft: controller.intervalTimeLeft,
                    formatMMSS: _formatMMSS,
                    config: config,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: LiveFTMSDataWidget(
                    ftmsDevice: ftmsDevice,
                    targets: controller.current.targets,
                    machineType: session.ftmsMachineType,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatMMSS(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
