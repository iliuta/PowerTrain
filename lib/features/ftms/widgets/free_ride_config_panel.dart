import 'package:flutter/material.dart';
import '../../../core/models/device_types.dart';
import '../../../core/config/live_data_display_config.dart';
import '../../settings/model/user_settings.dart';
import '../../training/widgets/edit_target_fields_widget.dart';
import '../models/session_selector_state.dart';
import '../../../l10n/app_localizations.dart';
import 'duration_distance_picker.dart';
import 'resistance_level_control.dart';

/// Callback for free ride configuration changes
typedef FreeRideConfigCallback = void Function(FreeRideConfig config);

/// A widget that displays the free ride session configuration panel
class FreeRideConfigPanel extends StatelessWidget {
  /// Current free ride configuration
  final FreeRideConfig config;

  /// Device type for device-specific options
  final DeviceType deviceType;

  /// User settings for target fields
  final UserSettings userSettings;

  /// Live data display config for target fields
  final LiveDataDisplayConfig displayConfig;

  /// Resistance capabilities
  final ResistanceCapabilities resistanceCapabilities;

  /// Selected GPX data (for distance adjustment)
  final double? selectedGpxDistance;

  /// Controller for resistance text field
  final TextEditingController? resistanceController;

  /// Callback when duration changes
  final void Function(int minutes) onDurationChanged;

  /// Callback when distance changes
  final void Function(int meters) onDistanceChanged;

  /// Callback when distance/duration mode changes
  final void Function(bool isDistanceBased) onModeChanged;

  /// Callback when target field changes
  final void Function(String name, dynamic value) onTargetChanged;

  /// Callback when resistance changes
  final void Function(int? userLevel) onResistanceChanged;

  /// Callback when warmup changes
  final void Function(bool hasWarmup) onWarmupChanged;

  /// Callback when cooldown changes
  final void Function(bool hasCooldown) onCooldownChanged;

  /// Callback when start button is pressed
  final VoidCallback onStart;

  const FreeRideConfigPanel({
    super.key,
    required this.config,
    required this.deviceType,
    required this.userSettings,
    required this.displayConfig,
    required this.resistanceCapabilities,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    required this.onModeChanged,
    required this.onTargetChanged,
    required this.onResistanceChanged,
    required this.onWarmupChanged,
    required this.onCooldownChanged,
    required this.onStart,
    this.selectedGpxDistance,
    this.resistanceController,
  });

  int get _distanceIncrement => FreeRideConfig.getDistanceIncrement(deviceType);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Duration/Distance picker
          DurationDistancePicker(
            isDistanceBased: config.isDistanceBased,
            durationMinutes: config.durationMinutes,
            distanceMeters: config.distanceMeters,
            distanceIncrement: _distanceIncrement,
            onModeChanged: onModeChanged,
            onDurationChanged: onDurationChanged,
            onDistanceChanged: onDistanceChanged,
          ),
          const SizedBox(height: 16),
          
          // Targets section
          Text(
            AppLocalizations.of(context)!.targets,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          EditTargetFieldsWidget(
            machineType: deviceType,
            userSettings: userSettings,
            config: displayConfig,
            targets: config.targets,
            onTargetChanged: onTargetChanged,
          ),
          const SizedBox(height: 16),
          
          // Resistance Level Control (only for rower and indoor bike)
          if (deviceType == DeviceType.rower || deviceType == DeviceType.indoorBike)
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
          
          // Warm-up and Cool-down checkboxes (only for rowers)
          if (deviceType == DeviceType.rower)
            _buildWarmupCooldownRow(context),
          
          // Start button
          ElevatedButton(
            onPressed: config.isResistanceLevelValid ? onStart : null,
            child: Text(AppLocalizations.of(context)!.start),
          ),
        ],
      ),
    );
  }

  Widget _buildWarmupCooldownRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Switch(
              value: config.hasWarmup,
              onChanged: onWarmupChanged,
            ),
            Text(AppLocalizations.of(context)!.warmUp),
          ],
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            Switch(
              value: config.hasCooldown,
              onChanged: onCooldownChanged,
            ),
            Text(AppLocalizations.of(context)!.coolDown),
          ],
        ),
      ],
    );
  }
}
