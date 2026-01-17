import 'package:flutter/material.dart';
import '../../../core/models/supported_resistance_level_range.dart';
import '../../../l10n/app_localizations.dart';
import '../../training/model/rower_workout_type.dart';
import 'expandable_card_section.dart';
import 'resistance_level_field.dart';

/// Widget for the Training Session Generator section (Rower only)
class TrainingSessionGeneratorSection extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onExpandChanged;
  final int durationMinutes;
  final RowerWorkoutType selectedWorkoutType;
  final int? resistanceLevel;
  final bool isResistanceValid;
  final TextEditingController resistanceController;
  final SupportedResistanceLevelRange? supportedResistanceRange;
  final String? selectedGpxAssetPath;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<RowerWorkoutType> onWorkoutTypeChanged;
  final ValueChanged<int?> onResistanceChanged;
  final VoidCallback onStartPressed;

  const TrainingSessionGeneratorSection({
    super.key,
    required this.isExpanded,
    required this.onExpandChanged,
    required this.durationMinutes,
    required this.selectedWorkoutType,
    required this.resistanceLevel,
    required this.isResistanceValid,
    required this.resistanceController,
    required this.supportedResistanceRange,
    required this.selectedGpxAssetPath,
    required this.onDurationChanged,
    required this.onWorkoutTypeChanged,
    required this.onResistanceChanged,
    required this.onStartPressed,
  });

  @override
  State<TrainingSessionGeneratorSection> createState() =>
      _TrainingSessionGeneratorSectionState();
}

class _TrainingSessionGeneratorSectionState
    extends State<TrainingSessionGeneratorSection> {
  @override
  Widget build(BuildContext context) {
    return ExpandableCardSection(
      title: AppLocalizations.of(context)!.trainingSessionGenerator,
      isExpanded: widget.isExpanded,
      onExpandChanged: widget.onExpandChanged,
      content: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // Duration Field (time-based only, minimum 15 minutes)
        const Text('Duration:'),
        const SizedBox(height: 8),
        _buildDurationSelector(),
        const SizedBox(height: 16),
        // Workout Type Selector
        const Text('Workout Type:'),
        const SizedBox(height: 8),
        _buildWorkoutTypeDropdown(context),
        const SizedBox(height: 16),
        // Resistance Level
        if (widget.supportedResistanceRange != null)
          ResistanceLevelField(
            resistanceLevel: widget.resistanceLevel,
            onChanged: widget.onResistanceChanged,
            supportedRange: widget.supportedResistanceRange!,
            isValid: widget.isResistanceValid,
            controller: widget.resistanceController,
          ),
        const SizedBox(height: 16),
        // Start Button
        ElevatedButton(
          onPressed: widget.isResistanceValid ? widget.onStartPressed : null,
          child: Text(AppLocalizations.of(context)!.start),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: widget.durationMinutes > 15
              ? () => widget.onDurationChanged(widget.durationMinutes - 1)
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${widget.durationMinutes} min',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: widget.durationMinutes < 120
              ? () => widget.onDurationChanged(widget.durationMinutes + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildWorkoutTypeDropdown(BuildContext context) {
    return DropdownButton<RowerWorkoutType>(
      value: widget.selectedWorkoutType,
      onChanged: (RowerWorkoutType? newValue) {
        if (newValue != null) {
          widget.onWorkoutTypeChanged(newValue);
        }
      },
      items: RowerWorkoutType.values
          .map<DropdownMenuItem<RowerWorkoutType>>((RowerWorkoutType value) {
        return DropdownMenuItem<RowerWorkoutType>(
          value: value,
          child: Text(value.strategy.getLabel(AppLocalizations.of(context)!)),
        );
      }).toList(),
    );
  }
}
