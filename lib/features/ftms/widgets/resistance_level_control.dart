import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';

/// Callback for resistance level changes
typedef ResistanceChangedCallback = void Function(int? userLevel);

/// A reusable widget for controlling resistance level with +/- buttons and text input
class ResistanceLevelControl extends StatelessWidget {
  /// Current user resistance level (1-based)
  final int? userResistanceLevel;

  /// Maximum resistance user input (1-based)
  final int maxResistanceUserInput;

  /// Whether the current value is valid
  final bool isValid;

  /// Whether resistance control is available on this device
  final bool isAvailable;

  /// Controller for the text field
  final TextEditingController? controller;

  /// Callback when resistance level changes
  final ResistanceChangedCallback onChanged;

  /// Optional callback for showing help dialog
  final VoidCallback? onShowHelp;

  const ResistanceLevelControl({
    super.key,
    required this.userResistanceLevel,
    required this.maxResistanceUserInput,
    required this.isValid,
    required this.isAvailable,
    required this.onChanged,
    this.controller,
    this.onShowHelp,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) {
      return _buildUnavailableMessage(context);
    }

    return _buildResistanceControl(context);
  }

  Widget _buildUnavailableMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.resistanceControlUnavailable,
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResistanceControl(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.resistance),
              if (onShowHelp != null)
                SizedBox(
                  height: 24,
                  width: 24,
                  child: IconButton(
                    icon: const Icon(Icons.help_outline, size: 16),
                    onPressed: onShowHelp,
                    tooltip: AppLocalizations.of(context)!.resistanceHelpMachine,
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (userResistanceLevel == null) {
                      onChanged(1);
                    } else if (userResistanceLevel! > 1) {
                      onChanged(userResistanceLevel! - 1);
                    }
                  },
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '(1-$maxResistanceUserInput)',
                      hintStyle: const TextStyle(fontSize: 12.0),
                      border: const OutlineInputBorder(),
                      errorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      isDense: true,
                      errorText: !isValid ? 'Invalid value (1-$maxResistanceUserInput)' : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: (value) {
                      if (value.isEmpty) {
                        onChanged(null);
                      } else {
                        final intValue = int.tryParse(value);
                        if (intValue != null) {
                          onChanged(intValue);
                        }
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (userResistanceLevel == null) {
                      onChanged(1);
                    } else if (userResistanceLevel! < maxResistanceUserInput) {
                      onChanged(userResistanceLevel! + 1);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the resistance machine support help dialog
void showResistanceMachineSupportDialog(BuildContext context, int maxResistanceUserInput) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context)!.resistanceHelpMachine),
        content: Text(
          AppLocalizations.of(context)!.resistanceHelpMachineDescription(maxResistanceUserInput.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      );
    },
  );
}
