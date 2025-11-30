import 'package:flutter/material.dart';
import '../training_session_controller.dart';

/// Handles session completion and confirmation dialogs
class SessionDialogManager {
  bool _congratulationsDialogShown = false;

  void handleCompletionDialog(
      BuildContext context, TrainingSessionController controller) {
    if (controller.state.hasEnded && !_congratulationsDialogShown) {
      _congratulationsDialogShown = true;
      _showCompletionDialog(context, controller);
    }
  }

  void _showCompletionDialog(
      BuildContext context, TrainingSessionController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: _buildCompletionDialogContent(context, controller),
        actions: [
          if (controller.lastGeneratedFitFile != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletionDialogContent(
      BuildContext context, TrainingSessionController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('You have completed the training session.'),
        if (controller.lastGeneratedFitFile != null) ...[
          if (controller.stravaUploadAttempted) ...[
            const SizedBox(height: 16),
            if (controller.stravaUploadSuccessful ||
                controller.stravaActivityId != null) ...[
              _buildSuccessRow(),
              if (controller.stravaActivityId != null) ...[
                const SizedBox(height: 4),
                _buildActivityIdText(context, controller.stravaActivityId!),
              ],
            ] else ...[
              _buildWarningRow(),
              const SizedBox(height: 4),
              _buildHelpText(context),
            ],
          ] else ...[
            const SizedBox(height: 8),
            const Text(
                'You can manually upload this file to Strava or other fitness apps.'),
          ],
        ],
      ],
    );
  }

  Widget _buildSuccessRow() {
    return const Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green, size: 20),
        SizedBox(width: 8),
        Text('Successfully uploaded to Strava!'),
      ],
    );
  }

  Widget _buildWarningRow() {
    return const Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange, size: 20),
        SizedBox(width: 8),
        Text('Strava upload in progress or failed'),
      ],
    );
  }

  Widget _buildActivityIdText(BuildContext context, String activityId) {
    return Text(
      'Activity ID: $activityId',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
    );
  }

  Widget _buildHelpText(BuildContext context) {
    return Text(
      'Make sure you\'re connected to Strava in settings',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
    );
  }
}
