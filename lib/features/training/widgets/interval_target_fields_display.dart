import 'package:flutter/material.dart';
import 'package:ftms/core/config/live_data_field_config.dart';

import '../../../core/config/live_data_display_config.dart';
import '../../../core/config/live_data_field_format_strategy.dart';
import '../../../core/widgets/live_data_icon_registry.dart';

class IntervalTargetFieldsDisplay extends StatelessWidget {
  final Map<String, dynamic>? targets;
  final LiveDataDisplayConfig? config;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const IntervalTargetFieldsDisplay({
    super.key,
    required this.targets,
    required this.config,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (targets == null || targets!.isEmpty) return const SizedBox.shrink();
    if (config == null) {
      // fallback: show raw
      return Text('Targets: $targets');
    }
    final List<Widget> children = [];
    for (final entry in targets!.entries) {
      final field = config!.fields.firstWhere(
        (f) => f.name == entry.key,
        orElse: () => LiveDataFieldConfig(
          name: entry.key,
          label: entry.key,
          display: 'number',
          unit: '',
        ),
      );
      
      // Format the value using the field's formatter if available
      String formattedValue = '${entry.value}${field.unit.isNotEmpty ? ' ${field.unit}' : ''}';
      if (field.formatter != null) {
        final formatterStrategy = LiveDataFieldFormatter.getStrategy(field.formatter!);
        if (formatterStrategy != null) {
          formattedValue = formatterStrategy.format(
            field: field, 
            paramValue: entry.value
          );
        }
      }
      
      children.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (field.icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(getLiveDataIcon(field.icon), size: 16),
            ),
          const SizedBox(width: 4),
          Flexible(
            flex: 1,
            child: Text(
              formattedValue,
              style: valueStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
