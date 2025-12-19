import 'package:flutter/material.dart';
import '../model/expanded_training_session_definition.dart';
import '../model/session_state.dart';
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
    final state = controller.state;
    final isWaitingForAutoStart = state.status == SessionStatus.created;
    
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
          if (isWaitingForAutoStart) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.hourglass_empty,
              color: Colors.blue,
              size: 16,
            ),
            const Text(
              'WAITING',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else if (state.isPaused) ...[
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
      actions: state.hasEnded
          ? null
          : [
              IconButton(
                onPressed: _getPlayPauseAction(),
                icon: Icon(_getPlayPauseIcon()),
                tooltip: _getPlayPauseTooltip(),
                color: _getPlayPauseColor(),
              ),
              IconButton(
                onPressed: onStopPressed,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop Session',
                color: Colors.red,
              ),
            ],
      toolbarHeight: 40,
    );
  }

  VoidCallback _getPlayPauseAction() {
    final state = controller.state;
    if (state.status == SessionStatus.created) {
      return controller.startSession;
    } else if (state.isPaused) {
      return controller.resumeSession;
    } else {
      return controller.pauseSession;
    }
  }

  IconData _getPlayPauseIcon() {
    final state = controller.state;
    if (state.status == SessionStatus.created || state.isPaused) {
      return Icons.play_arrow;
    } else {
      return Icons.pause;
    }
  }

  String _getPlayPauseTooltip() {
    final state = controller.state;
    if (state.status == SessionStatus.created) {
      return 'Start';
    } else if (state.isPaused) {
      return 'Resume';
    } else {
      return 'Pause';
    }
  }

  Color _getPlayPauseColor() {
    final state = controller.state;
    if (state.status == SessionStatus.created || state.isPaused) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(40);
}
