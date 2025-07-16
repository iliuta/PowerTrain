import 'package:flutter/material.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/config/live_data_field_format_strategy.dart';

import '../models/live_data_field_value.dart';
import 'live_data_icon_registry.dart';

/// Widget for displaying a value as a simple number with label.
class SimpleNumberWidget extends StatelessWidget {
  final LiveDataFieldConfig displayField;
  final Color? color;
  final LiveDataFieldValue param;
  const SimpleNumberWidget(this.displayField, this.param, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    IconData? iconData = getLiveDataIcon(displayField.icon);
    final scaledValue = param.getScaledValue();

    String formattedValue = '${scaledValue.toStringAsFixed(0)} ${displayField.unit}';
    if (displayField.formatter != null) {
      final formatterStrategy =
      LiveDataFieldFormatter.getStrategy(displayField.formatter!);
      if (formatterStrategy != null) {
        formattedValue = formatterStrategy.format(
            field: displayField, paramValue: scaledValue);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayField.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (iconData != null)
              Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: Icon(iconData, size: 16, color: Colors.grey[600]),
              ),
          ],
        ),
        Text(formattedValue, style: TextStyle(fontSize: 22, color: color)),
      ],
    );
  }
}
