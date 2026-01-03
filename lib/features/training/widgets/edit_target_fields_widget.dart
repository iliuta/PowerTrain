import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/config/live_data_field_format_strategy.dart';
import 'package:ftms/core/utils/i18n_utils.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/model/target_power_strategy.dart';
import 'package:ftms/l10n/app_localizations.dart';

class EditTargetFieldsWidget extends StatelessWidget {
  final DeviceType machineType;
  final UserSettings userSettings;
  final LiveDataDisplayConfig config;
  final Map<String, dynamic> targets;
  final Function(String, dynamic) onTargetChanged;

  const EditTargetFieldsWidget({
    super.key,
    required this.machineType,
    required this.userSettings,
    required this.config,
    required this.targets,
    required this.onTargetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final availableTargetFields = config.fields.where((field) => field.availableAsTarget).toList();

    return Column(
      children: availableTargetFields.map((field) => _buildTargetField(context, field)).toList(),
    );
  }

  Widget _buildTargetField(BuildContext context, LiveDataFieldConfig field) {
    final currentValue = targets[field.name];

    // Fields with userSetting always use percentage input
    final bool canShowPercentage = field.userSetting != null;

    String initialPercentage = '';
    if (canShowPercentage && currentValue != null) {
      final percentageString = currentValue.replaceAll('%', '');
      final percentage = double.tryParse(percentageString);
      if (percentage != null) {
        initialPercentage = percentage.round().toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('${getFieldLabel(field, Localizations.localeOf(context).languageCode)}:'),
          ),
          Expanded(
            child: canShowPercentage
                ? Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: initialPercentage,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.examplePercentage,
                            suffixText: '%',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3), // Max 3 digits for percentage
                          ],
                          onChanged: (value) {
                            if (value.isEmpty) {
                              onTargetChanged(field.name, null);
                              return;
                            }
                            final percentage = int.tryParse(value);
                            if (percentage != null && percentage >= 0 && percentage <= 200) {
                              onTargetChanged(field.name, '$percentage%');
                            }
                          },
                        ),
                      ),
                    ],
                  )
                : TextFormField(
                    initialValue: currentValue?.toString() ?? '',
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.enterValue,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (value) {
                      if (value.isEmpty) {
                        onTargetChanged(field.name, null);
                        return;
                      }
                      final numValue = num.tryParse(value);
                      if (numValue != null) {
                        onTargetChanged(field.name, numValue);
                      }
                    },
                  ),
          ),
          // Show calculated absolute value for percentage inputs
          if (canShowPercentage && currentValue != null)
            SizedBox(
              width: 80,
              child: Text(
                _formatAbsoluteValueFromPercentage(field, currentValue),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }


  double _calculateValueFromPercentage(double percentage) {
    // Use the existing target power strategy
    final strategy = TargetPowerStrategyFactory.getStrategy(machineType);

    // Create a percentage string and let the strategy resolve it
    final percentageString = '${percentage.round()}%';
    final resolvedValue = strategy.resolvePower(percentageString, userSettings);

    // If the strategy resolved it to a number, use that; otherwise return 0
    if (resolvedValue is num) {
      return resolvedValue.toDouble();
    }

    // Return 0 if strategy couldn't resolve the percentage
    return 0.0;
  }

  String _formatAbsoluteValueFromPercentage(LiveDataFieldConfig field, dynamic value) {
    if (value == null) return '';

    // Extract percentage from string (e.g., "85%" -> 85)
    double percentage = 0;
    if (value is String && value.endsWith('%')) {
      final percentageString = value.replaceAll('%', '');
      percentage = double.tryParse(percentageString) ?? 0;
    } else if (value is num) {
      // If it's already a number, treat it as a percentage
      percentage = value.toDouble();
    }

    if (percentage <= 0) return '';

    // Calculate absolute value using the strategy
    final absoluteValue = _calculateValueFromPercentage(percentage);

    // Apply formatter if available
    if (field.formatter != null) {
      final strategy = LiveDataFieldFormatter.getStrategy(field.formatter!);
      if (strategy != null) {
        final formattedValue = strategy.format(field: field, paramValue: absoluteValue);
        return '≈ $formattedValue';
      }
    }

    // Default formatting with unit
    return '≈ ${absoluteValue.round()} ${field.unit}';
  }
}