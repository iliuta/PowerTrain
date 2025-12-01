import 'package:flutter/material.dart';
import '../model/expanded_training_session_definition.dart';
import '../training_session_controller.dart';

/// App bar for the training session screen
class TrainingSessionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final ExpandedTrainingSessionDefinition session;
  final TrainingSessionController controller;
  final VoidCallback onBackPressed;
  final VoidCallback onStopPressed;

  const TrainingSessionAppBar({
    super.key,
    required this.session,
    required this.controller,
    required this.onBackPressed,
    required this.onStopPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackPressed,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              session.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (controller.state.isPaused) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.pause_circle,
              color: Colors.orange,
              size: 16,
            ),
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      actions: controller.state.hasEnded
          ? null
          : [
              IconButton(
                onPressed: controller.state.isPaused
                    ? controller.resumeSession
                    : controller.pauseSession,
                icon: Icon(
                    controller.state.isPaused ? Icons.play_arrow : Icons.pause),
                tooltip: controller.state.isPaused ? 'Resume' : 'Pause',
                color: controller.state.isPaused ? Colors.green : Colors.orange,
              ),
              IconButton(
                onPressed: onStopPressed,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop Session',
                color: Colors.red,
              ),
            ],
      toolbarHeight: 56,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
