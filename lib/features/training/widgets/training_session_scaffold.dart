import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import '../../../core/config/live_data_display_config.dart';
import '../model/expanded_training_session_definition.dart';
import '../training_session_controller.dart';
import '../managers/session_snackbar_manager.dart';
import 'route_map_widget.dart';
import 'training_session_app_bar.dart';
import 'training_session_body.dart';

/// Main scaffold widget for the training session
class TrainingSessionScaffold extends StatefulWidget {
  final ExpandedTrainingSessionDefinition session;
  final TrainingSessionController controller;
  final LiveDataDisplayConfig? config;
  final BluetoothDevice ftmsDevice;

  const TrainingSessionScaffold({
    super.key,
    required this.session,
    required this.controller,
    this.config,
    required this.ftmsDevice,
  });

  @override
  State<TrainingSessionScaffold> createState() =>
      _TrainingSessionScaffoldState();
}

class _TrainingSessionScaffoldState extends State<TrainingSessionScaffold> {
  final _snackBarManager = SessionSnackBarManager();
  bool _confirmationDialogShown = false;

  void _onBackPressed() {
    if (!widget.controller.state.hasEnded) {
      _showStopConfirmationDialog();
    }
  }

  void _onStopPressed() {
    if (!widget.controller.state.hasEnded) {
      _showStopConfirmationDialog();
    }
  }

  void _showStopConfirmationDialog({bool isSessionComplete = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _StopConfirmationDialog(
        controller: widget.controller,
        isSessionComplete: isSessionComplete,
        onStop: () {
          _confirmationDialogShown = true;
          widget.controller.stopSession();
        },
        onDiscard: () {
          _confirmationDialogShown = true;
          Navigator.of(dialogContext).pop();
          Navigator.of(context).pop();
          if (!isSessionComplete) {
            widget.controller.discardSession();
          }
        },
        onSaveComplete: () {
          // Show success snackbar before navigating back
          _showSaveSuccessSnackBar();
          Navigator.of(dialogContext).pop();
          // Navigate back after a brief delay to show the snackbar
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle post-frame callbacks for dialogs and snackbars
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Show confirmation dialog when session completes naturally
      if (widget.controller.state.hasEnded && !_confirmationDialogShown) {
        _confirmationDialogShown = true;
        _showStopConfirmationDialog(isSessionComplete: true);
      }
      _snackBarManager.handlePauseSnackBar(context, widget.controller);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !widget.controller.state.hasEnded) {
          _showStopConfirmationDialog();
        }
      },
      child: Stack(
        children: [
          // Main scaffold with all UI
          Scaffold(
            appBar: TrainingSessionAppBar(
              session: widget.session,
              controller: widget.controller,
              onBackPressed: _onBackPressed,
              onStopPressed: _onStopPressed,
            ),
            body: TrainingSessionBody(
              session: widget.session,
              controller: widget.controller,
              config: widget.config,
              ftmsDevice: widget.ftmsDevice,
            ),
          ),
          // Route map overlay (non-interactive)
          IgnorePointer(
            child: RouteMapWidget(
              gpxTracker: widget.controller.gpxRouteTracker,
            ),
          ),
        ],
      ),
    );
  }

  void _showSaveSuccessSnackBar() {
    final message = widget.controller.stravaUploadAttempted
        ? (widget.controller.stravaUploadSuccessful
            ? 'Workout saved and uploaded to Strava!'
            : 'Workout saved (Strava not connected)')
        : 'Workout saved!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Unified confirmation dialog for stopping/completing training session
class _StopConfirmationDialog extends StatefulWidget {
  final TrainingSessionController controller;
  final bool isSessionComplete;
  final VoidCallback onDiscard;
  final VoidCallback onSaveComplete;
  final VoidCallback? onStop;

  const _StopConfirmationDialog({
    required this.controller,
    required this.isSessionComplete,
    required this.onDiscard,
    required this.onSaveComplete,
    this.onStop,
  });

  @override
  State<_StopConfirmationDialog> createState() => _StopConfirmationDialogState();
}

class _StopConfirmationDialogState extends State<_StopConfirmationDialog> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isSessionComplete ? 'Congratulations!' : 'Stop Training Session'),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_isSaving) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Saving workout...'),
        ],
      );
    }

    // Initial state
    if (widget.isSessionComplete) {
      return const Text('You have completed the training session. Would you like to save your workout?');
    }
    return const Text('Are you sure you want to stop the training session? This action cannot be undone.');
  }

  List<Widget> _buildActions() {
    if (_isSaving) {
      return [];
    }

    return [
      if (!widget.isSessionComplete)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ElevatedButton(
        onPressed: widget.onDiscard,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('Discard'),
      ),
      ElevatedButton(
        onPressed: _saveWorkout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        child: const Text('Save'),
      ),
    ];
  }

  Future<void> _saveWorkout() async {
    setState(() => _isSaving = true);

    if (!widget.isSessionComplete) {
      if (widget.onStop != null) {
        widget.onStop!();
      } else {
        widget.controller.stopSession();
      }
    }
    await widget.controller.saveRecording();

    if (mounted) {
      // Close dialog and navigate back after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          widget.onSaveComplete();
        }
      });
    }
  }
}
