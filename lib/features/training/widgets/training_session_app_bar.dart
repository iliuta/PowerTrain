import 'package:flutter/material.dart';
import '../model/expanded_training_session_definition.dart';
import '../training_session_controller.dart';

/// App bar for the training session screen
class TrainingSessionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final ExpandedTrainingSessionDefinition session;
  final TrainingSessionController controller;

  const TrainingSessionAppBar({
    super.key,
    required this.session,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _showStopConfirmationDialog(context),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              session.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (controller.sessionPaused) ...[
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
      actions: controller.sessionCompleted
          ? null
          : [
              IconButton(
                onPressed: controller.sessionPaused
                    ? controller.resumeSession
                    : controller.pauseSession,
                icon: Icon(
                    controller.sessionPaused ? Icons.play_arrow : Icons.pause),
                tooltip: controller.sessionPaused ? 'Resume' : 'Pause',
                color: controller.sessionPaused ? Colors.green : Colors.orange,
              ),
              IconButton(
                onPressed: () => _showStopConfirmationDialog(context),
                icon: const Icon(Icons.stop),
                tooltip: 'Stop Session',
                color: Colors.red,
              ),
            ],
      toolbarHeight: 56,
    );
  }

  void _showStopConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Training Session'),
        content: const Text(
          'Are you sure you want to stop the training session? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              controller.discardSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              controller.stopSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save and stop'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
