import 'package:flutter/material.dart';
import 'package:ftms/l10n/app_localizations.dart';
import '../../../core/services/user_settings_service.dart';
import '../../settings/model/user_settings.dart';
import '../model/expanded_training_session_definition.dart';
import '../model/session_state.dart';
import '../training_session_controller.dart';
import 'metronome_visualizer.dart';

/// App bar for the training session screen
class TrainingSessionAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  final ExpandedTrainingSessionDefinition session;
  final TrainingSessionController controller;
  final VoidCallback onBackPressed;
  final VoidCallback onStopPressed;
  final UserSettings userSettings;

  const TrainingSessionAppBar({
    super.key,
    required this.session,
    required this.controller,
    required this.onBackPressed,
    required this.onStopPressed,
    required this.userSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  State<TrainingSessionAppBar> createState() => _TrainingSessionAppBarState();
}

class _TrainingSessionAppBarState extends State<TrainingSessionAppBar> {
  late bool _metronomeSoundEnabled;
  late bool _alertsSoundEnabled;

  @override
  void initState() {
    super.initState();
    _metronomeSoundEnabled = widget.userSettings.metronomeSoundEnabled;
    _alertsSoundEnabled = widget.userSettings.soundEnabled;
  }

  Future<void> _toggleMetronomeSound() async {
    final newValue = !_metronomeSoundEnabled;
    await UserSettingsService.instance.setMetronomeSoundEnabled(newValue);
    setState(() {
      _metronomeSoundEnabled = newValue;
    });
  }

  Future<void> _toggleAlertsSound() async {
    final newValue = !_alertsSoundEnabled;
    await UserSettingsService.instance.setSoundEnabled(newValue);
    setState(() {
      _alertsSoundEnabled = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final isWaitingForAutoStart = state.status == SessionStatus.created;
    
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onBackPressed,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              widget.session.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Metronome visualizer - compact version in app bar
          if (widget.controller.currentMetronomeTarget != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: MetronomeVisualizer(
                targetCadence: widget.controller.currentMetronomeTarget!,
                tickCount: widget.controller.metronomeTickCount,
                isPullPhase: widget.controller.isPullPhase,
              ),
            ),
          ],
          if (isWaitingForAutoStart) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.hourglass_empty,
              color: Colors.blue,
              size: 16,
            ),
            Text(
              AppLocalizations.of(context)!.waiting,
              style: const TextStyle(
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
            Text(
              AppLocalizations.of(context)!.paused,
              style: const TextStyle(
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
              // Metronome sound toggle button
              IconButton(
                onPressed: _toggleMetronomeSound,
                icon: _metronomeSoundEnabled
                    ? Image.asset(
                        'assets/icons/metronome.png',
                        width: 24,
                        height: 24,
                        color: Colors.blue,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/metronome.png',
                            width: 24,
                            height: 24,
                            color: Colors.grey,
                          ),
                          const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red,
                          ),
                        ],
                      ),
                tooltip: _metronomeSoundEnabled ? 'Disable Metronome' : 'Enable Metronome',
              ),
              // Alerts sound toggle button
              IconButton(
                onPressed: _toggleAlertsSound,
                icon: _alertsSoundEnabled
                    ? const Icon(Icons.notifications)
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.notifications),
                          const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red,
                          ),
                        ],
                      ),
                tooltip: _alertsSoundEnabled ? 'Disable Alerts' : 'Enable Alerts',
                color: _alertsSoundEnabled ? Colors.blue : Colors.grey,
              ),
              IconButton(
                onPressed: _getPlayPauseAction(),
                icon: Icon(_getPlayPauseIcon()),
                tooltip: _getPlayPauseTooltip(),
                color: _getPlayPauseColor(),
              ),
              IconButton(
                onPressed: widget.onStopPressed,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop Session',
                color: Colors.red,
              ),
            ],
      toolbarHeight: 40,
    );
  }

  VoidCallback _getPlayPauseAction() {
    final state = widget.controller.state;
    if (state.status == SessionStatus.created) {
      return widget.controller.startSession;
    } else if (state.isPaused) {
      return widget.controller.resumeSession;
    } else {
      return widget.controller.pauseSession;
    }
  }

  IconData _getPlayPauseIcon() {
    final state = widget.controller.state;
    if (state.status == SessionStatus.created || state.isPaused) {
      return Icons.play_arrow;
    } else {
      return Icons.pause;
    }
  }

  String _getPlayPauseTooltip() {
    final state = widget.controller.state;
    if (state.status == SessionStatus.created) {
      return 'Start';
    } else if (state.isPaused) {
      return 'Resume';
    } else {
      return 'Pause';
    }
  }

  Color _getPlayPauseColor() {
    final state = widget.controller.state;
    if (state.status == SessionStatus.created || state.isPaused) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }
}
