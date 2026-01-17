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

class EditTargetFieldsWidget extends StatefulWidget {
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
  State<EditTargetFieldsWidget> createState() => _EditTargetFieldsWidgetState();
}

class _EditTargetFieldsWidgetState extends State<EditTargetFieldsWidget> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _controllers = {};
    final availableTargetFields = widget.config.fields.where((field) => field.availableAsTarget).toList();
    
    for (final field in availableTargetFields) {
      final currentValue = widget.targets[field.name];
      final bool canShowPercentage = field.userSetting != null;
      
      String initialValue = '';
      if (currentValue != null) {
        if (canShowPercentage) {
          final percentageString = currentValue.toString().replaceAll('%', '');
          final percentage = double.tryParse(percentageString);
          if (percentage != null) {
            initialValue = percentage.round().toString();
          }
        } else {
          initialValue = currentValue.toString();
        }
      }
      
      _controllers[field.name] = TextEditingController(text: initialValue);
    }
  }

  @override
  void didUpdateWidget(EditTargetFieldsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers when targets change externally
    for (final entry in _controllers.entries) {
      final currentValue = widget.targets[entry.key];
      final field = widget.config.fields.firstWhere((f) => f.name == entry.key);
      final bool canShowPercentage = field.userSetting != null;
      
      String newValue = '';
      if (currentValue != null) {
        if (canShowPercentage) {
          final percentageString = currentValue.toString().replaceAll('%', '');
          final percentage = double.tryParse(percentageString);
          if (percentage != null) {
            newValue = percentage.round().toString();
          }
        } else {
          newValue = currentValue.toString();
        }
      }
      
      if (entry.value.text != newValue) {
        entry.value.text = newValue;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableTargetFields = widget.config.fields.where((field) => field.availableAsTarget).toList();

    return Column(
      children: availableTargetFields.map((field) => _buildTargetField(context, field)).toList(),
    );
  }

  Widget _buildTargetField(BuildContext context, LiveDataFieldConfig field) {
    final currentValue = widget.targets[field.name];
    final controller = _controllers[field.name]!;

    // Fields with userSetting always use percentage input
    final bool canShowPercentage = field.userSetting != null;

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
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.examplePercentage,
                            suffixText: '%',
                            suffixIcon: currentValue != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      widget.onTargetChanged(field.name, null);
                                    },
                                  )
                                : null,
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
                              widget.onTargetChanged(field.name, null);
                              return;
                            }
                            final percentage = int.tryParse(value);
                            if (percentage != null && percentage >= 0 && percentage <= 200) {
                              widget.onTargetChanged(field.name, '$percentage%');
                            }
                          },
                        ),
                      ),
                    ],
                  )
                : TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.enterValue,
                      suffixIcon: currentValue != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                controller.clear();
                                widget.onTargetChanged(field.name, null);
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (value) {
                      if (value.isEmpty) {
                        widget.onTargetChanged(field.name, null);
                        return;
                      }
                      final numValue = num.tryParse(value);
                      if (numValue != null) {
                        widget.onTargetChanged(field.name, numValue);
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
    final strategy = TargetPowerStrategyFactory.getStrategy(widget.machineType);

    // Create a percentage string and let the strategy resolve it
    final percentageString = '${percentage.round()}%';
    final resolvedValue = strategy.resolvePower(percentageString, widget.userSettings);

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