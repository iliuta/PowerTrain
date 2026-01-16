import 'package:flutter/material.dart';
import '../../../core/models/device_types.dart';
import '../../../core/models/supported_resistance_level_range.dart';
import '../../../l10n/app_localizations.dart';
import '../../training/widgets/edit_target_fields_widget.dart';
import '../../../core/config/live_data_display_config.dart';
import '../../../features/settings/model/user_settings.dart';
import 'duration_distance_selector.dart';
import 'expandable_card_section.dart';
import 'resistance_level_field.dart';

/// Widget for the Free Ride section
class FreeRideSection extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onExpandChanged;
  final DeviceType? deviceType;
  final int durationMinutes;
  final bool isDistanceBased;
  final int distanceMeters;
  final int distanceIncrement;
  final Map<String, dynamic> targets;
  final int? resistanceLevel;
  final bool isResistanceValid;
  final TextEditingController resistanceController;
  final SupportedResistanceLevelRange? supportedResistanceRange;
  final bool hasWarmup;
  final bool hasCooldown;
  final UserSettings? userSettings;
  final Map<DeviceType, LiveDataDisplayConfig?> configs;
  final String? selectedGpxAssetPath;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onDistanceChanged;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<Map<String, dynamic>> onTargetsChanged;
  final ValueChanged<int?> onResistanceChanged;
  final ValueChanged<bool> onWarmupChanged;
  final ValueChanged<bool> onCooldownChanged;
  final VoidCallback onStartPressed;

  const FreeRideSection({
    super.key,
    required this.isExpanded,
    required this.onExpandChanged,
    required this.deviceType,
    required this.durationMinutes,
    required this.isDistanceBased,
    required this.distanceMeters,
    required this.distanceIncrement,
    required this.targets,
    required this.resistanceLevel,
    required this.isResistanceValid,
    required this.resistanceController,
    required this.supportedResistanceRange,
    required this.hasWarmup,
    required this.hasCooldown,
    required this.userSettings,
    required this.configs,
    required this.selectedGpxAssetPath,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    required this.onModeChanged,
    required this.onTargetsChanged,
    required this.onResistanceChanged,
    required this.onWarmupChanged,
    required this.onCooldownChanged,
    required this.onStartPressed,
  });

  @override
  State<FreeRideSection> createState() => _FreeRideSectionState();
}

class _FreeRideSectionState extends State<FreeRideSection> {
  @override
  Widget build(BuildContext context) {
    return ExpandableCardSection(
      title: AppLocalizations.of(context)!.freeRide,
      isExpanded: widget.isExpanded,
      onExpandChanged: widget.onExpandChanged,
      content: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // Duration/Distance Selector
        DurationDistanceSelector(
          isDistanceBased: widget.isDistanceBased,
          durationMinutes: widget.durationMinutes,
          distanceMeters: widget.distanceMeters,
          distanceIncrement: widget.distanceIncrement,
          onDurationChanged: widget.onDurationChanged,
          onDistanceChanged: widget.onDistanceChanged,
          onModeChanged: widget.onModeChanged,
        ),
        const SizedBox(height: 16),
        // Targets
        Text(
          AppLocalizations.of(context)!.targets,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (widget.deviceType != null &&
            widget.userSettings != null &&
            widget.configs[widget.deviceType!] != null)
          EditTargetFieldsWidget(
            machineType: widget.deviceType!,
            userSettings: widget.userSettings!,
            config: widget.configs[widget.deviceType!]!,
            targets: widget.targets,
            onTargetChanged: (name, value) {
              final newTargets = Map<String, dynamic>.from(widget.targets);
              if (value == null) {
                newTargets.remove(name);
              } else {
                newTargets[name] = value;
              }
              widget.onTargetsChanged(newTargets);
            },
          ),
        const SizedBox(height: 16),
        // Resistance Level
        if (widget.deviceType != null &&
            (widget.deviceType! == DeviceType.rower ||
                widget.deviceType! == DeviceType.indoorBike) &&
            widget.supportedResistanceRange != null)
          ResistanceLevelField(
            resistanceLevel: widget.resistanceLevel,
            onChanged: widget.onResistanceChanged,
            supportedRange: widget.supportedResistanceRange!,
            isValid: widget.isResistanceValid,
            controller: widget.resistanceController,
          ),
        const SizedBox(height: 16),
        // Warmup/Cooldown (only for rowers)
        if (widget.deviceType != null && widget.deviceType! == DeviceType.rower)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Switch(
                    value: widget.hasWarmup,
                    onChanged: widget.onWarmupChanged,
                  ),
                  Text(AppLocalizations.of(context)!.warmUp),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Switch(
                    value: widget.hasCooldown,
                    onChanged: widget.onCooldownChanged,
                  ),
                  Text(AppLocalizations.of(context)!.coolDown),
                ],
              ),
            ],
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
}
