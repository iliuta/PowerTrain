import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import '../../../core/config/live_data_display_config.dart';
import '../model/expanded_training_session_definition.dart';
import '../training_session_controller.dart';
import '../managers/session_dialog_manager.dart';
import '../managers/session_snackbar_manager.dart';
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
  final _dialogManager = SessionDialogManager();
  final _snackBarManager = SessionSnackBarManager();

  void _showStopConfirmationDialog() {
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
              widget.controller.discardSession();
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
              widget.controller.stopSession();
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
  Widget build(BuildContext context) {
    // Handle post-frame callbacks for dialogs and snackbars
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogManager.handleCompletionDialog(context, widget.controller);
      _snackBarManager.handlePauseSnackBar(context, widget.controller);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showStopConfirmationDialog();
        }
      },
      child: Scaffold(
        appBar: TrainingSessionAppBar(
          session: widget.session,
          controller: widget.controller,
          onBackPressed: _showStopConfirmationDialog,
          onStopPressed: _showStopConfirmationDialog,
        ),
        body: TrainingSessionBody(
          session: widget.session,
          controller: widget.controller,
          config: widget.config,
          ftmsDevice: widget.ftmsDevice,
        ),
      ),
    );
  }
}
