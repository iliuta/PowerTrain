import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/supported_resistance_level_range.dart';
import '../../../l10n/app_localizations.dart';

/// Reusable widget for selecting a resistance level with increment/decrement buttons
class ResistanceLevelField extends StatefulWidget {
  final int? resistanceLevel;
  final ValueChanged<int?> onChanged;
  final SupportedResistanceLevelRange supportedRange;
  final bool isValid;
  final TextEditingController controller;

  const ResistanceLevelField({
    super.key,
    required this.resistanceLevel,
    required this.onChanged,
    required this.supportedRange,
    required this.isValid,
    required this.controller,
  });

  @override
  State<ResistanceLevelField> createState() => _ResistanceLevelFieldState();
}

class _ResistanceLevelFieldState extends State<ResistanceLevelField> {
  void _decrementResistance() {
    int? newValue;
    if (widget.resistanceLevel == null) {
      newValue = widget.supportedRange.minResistanceLevel;
    } else if (widget.resistanceLevel! > widget.supportedRange.minResistanceLevel) {
      newValue = widget.resistanceLevel! - widget.supportedRange.minIncrement;
      if (newValue < widget.supportedRange.minResistanceLevel) {
        newValue = widget.supportedRange.minResistanceLevel;
      }
    }
    if (newValue != null) {
      widget.onChanged(newValue);
    }
  }

  void _incrementResistance() {
    int? newValue;
    if (widget.resistanceLevel == null) {
      newValue = widget.supportedRange.minResistanceLevel;
    } else if (widget.resistanceLevel! < widget.supportedRange.maxResistanceLevel) {
      newValue = widget.resistanceLevel! + widget.supportedRange.minIncrement;
      if (newValue > widget.supportedRange.maxResistanceLevel) {
        newValue = widget.supportedRange.maxResistanceLevel;
      }
    }
    if (newValue != null) {
      widget.onChanged(newValue);
    }
  }

  void _handleTextChange(String value) {
    if (value.isEmpty) {
      widget.onChanged(null);
    } else {
      final intValue = int.tryParse(value);
      if (intValue != null &&
          intValue >= widget.supportedRange.minResistanceLevel &&
          intValue <= widget.supportedRange.maxResistanceLevel &&
          (intValue - widget.supportedRange.minResistanceLevel) %
                  widget.supportedRange.minIncrement ==
              0) {
        widget.onChanged(intValue);
      } else {
        // Invalid value, don't update but allow UI to show error
      }
    }
  }

  void _clearValue() {
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(AppLocalizations.of(context)!.resistance),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _decrementResistance,
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: widget.controller,
                    decoration: InputDecoration(
                      hintText:
                          '(${widget.supportedRange.minResistanceLevel}-${widget.supportedRange.maxResistanceLevel})',
                      hintStyle: const TextStyle(fontSize: 12.0),
                      border: const OutlineInputBorder(),
                      errorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      isDense: true,
                      errorText: !widget.isValid
                          ? 'Invalid value (must be multiple of ${widget.supportedRange.minIncrement})'
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      suffixIcon: widget.resistanceLevel != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearValue,
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: _handleTextChange,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _incrementResistance,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
