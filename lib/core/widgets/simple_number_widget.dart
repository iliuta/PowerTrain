import 'package:flutter/material.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/config/live_data_field_format_strategy.dart';
import 'package:ftms/core/utils/i18n_utils.dart';
import 'package:ftms/core/utils/responsive_utils.dart';
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
    final scale = ResponsiveUtils.scaleFactor(context);

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
            Text(getFieldLabel(displayField, Localizations.localeOf(context).languageCode), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * scale)),
            if (iconData != null)
              Padding(
                padding: EdgeInsets.only(left: 6.0 * scale),
                child: Icon(iconData, size: 16 * scale, color: Colors.grey[600]),
              ),
          ],
        ),
        Text(formattedValue, style: TextStyle(fontSize: 22 * scale, color: color)),
      ],
    );
  }
}
