import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../training_session_controller.dart';

/// Handles pause/resume snackbar messages
class SessionSnackBarManager {
  bool _pauseSnackBarShown = false;

  void handlePauseSnackBar(
      BuildContext context, TrainingSessionController controller) {
    if (controller.state.isPaused &&
        !_pauseSnackBarShown &&
        !controller.state.hasEnded) {
      _showPauseSnackBar(context, controller);
    } else if (!controller.state.isPaused && _pauseSnackBarShown) {
      _hidePauseSnackBar(context);
    }
  }

  void _showPauseSnackBar(
      BuildContext context, TrainingSessionController controller) {
    _pauseSnackBarShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.pause_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.sessionPaused),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.resume,
          textColor: Colors.white,
          onPressed: controller.resumeSession,
        ),
      ),
    );
  }

  void _hidePauseSnackBar(BuildContext context) {
    _pauseSnackBarShown = false;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
