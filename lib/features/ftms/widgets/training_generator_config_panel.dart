import 'package:flutter/material.dart';
import '../../training/model/rower_workout_type.dart';
import '../models/session_selector_state.dart';
import '../../../l10n/app_localizations.dart';
import 'duration_distance_picker.dart';
import 'resistance_level_control.dart';

/// A widget that displays the training session generator configuration panel
class TrainingGeneratorConfigPanel extends StatelessWidget {
  /// Current training generator configuration
  final TrainingGeneratorConfig config;

  /// Resistance capabilities
  final ResistanceCapabilities resistanceCapabilities;

  /// Controller for resistance text field
  final TextEditingController? resistanceController;

  /// Callback when duration changes
  final void Function(int minutes) onDurationChanged;

  /// Callback when workout type changes
  final void Function(RowerWorkoutType workoutType) onWorkoutTypeChanged;

  /// Callback when resistance changes
  final void Function(int? userLevel) onResistanceChanged;

  /// Callback when start button is pressed
  final VoidCallback onStart;

  const TrainingGeneratorConfigPanel({
    super.key,
    required this.config,
    required this.resistanceCapabilities,
    required this.onDurationChanged,
    required this.onWorkoutTypeChanged,
    required this.onResistanceChanged,
    required this.onStart,
    this.resistanceController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Duration Field (time-based only, minimum 15 minutes)
          DurationPicker(
            label: 'Duration:',
            durationMinutes: config.durationMinutes,
            minMinutes: 15,
            maxMinutes: 120,
            onChanged: onDurationChanged,
          ),
          const SizedBox(height: 16),
          
          // Workout Type Selector
          Text('Workout Type:'),
          const SizedBox(height: 8),
          DropdownButton<RowerWorkoutType>(
            value: config.workoutType,
            onChanged: (RowerWorkoutType? newValue) {
              if (newValue != null) {
                onWorkoutTypeChanged(newValue);
              }
            },
            items: RowerWorkoutType.values.map<DropdownMenuItem<RowerWorkoutType>>((RowerWorkoutType value) {
              return DropdownMenuItem<RowerWorkoutType>(
                value: value,
                child: Text(value.strategy.getLabel(AppLocalizations.of(context)!)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Resistance Level Control (only if supported)
          ResistanceLevelControl(
            userResistanceLevel: config.userResistanceLevel,
            maxResistanceUserInput: resistanceCapabilities.maxUserInput,
            isValid: config.isResistanceLevelValid,
            isAvailable: resistanceCapabilities.isAvailable,
            controller: resistanceController,
            onChanged: onResistanceChanged,
            onShowHelp: () => showResistanceMachineSupportDialog(
              context,
              resistanceCapabilities.maxUserInput,
            ),
          ),
          const SizedBox(height: 16),
          
          // Start Button
          ElevatedButton(
            onPressed: config.isResistanceLevelValid ? onStart : null,
            child: Text(AppLocalizations.of(context)!.start),
          ),
        ],
      ),
    );
  }
}
