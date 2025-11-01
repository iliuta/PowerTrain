import 'package:flutter/material.dart';
import 'package:ftms/core/models/device_types.dart';
import '../config/live_data_display_config.dart';
import '../config/live_data_field_config.dart';
import '../models/live_data_field_value.dart';
import 'live_data_field_widget.dart';

/// Shared widget for displaying FTMS live data fields according to config.
class FtmsLiveDataDisplayWidget extends StatelessWidget {
  final LiveDataDisplayConfig config;
  final Map<String, LiveDataFieldValue> paramValueMap;
  final Map<String, dynamic>? targets;
  final Color? defaultColor;
  final DeviceType? machineType;
  const FtmsLiveDataDisplayWidget({
    super.key,
    required this.config,
    required this.paramValueMap,
    this.targets,
    this.defaultColor,
    this.machineType,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final orientation = MediaQuery.of(context).orientation;
        final int columns = orientation == Orientation.portrait ? 3 : 4;
        final rows = _buildRows(columns);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows.map((row) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: row,
          )).toList(),
        );
      },
    );
  }

  List<List<Widget>> _buildRows(int columns) {
    final List<List<Widget>> rows = [];
    List<Widget> currentRow = [];
    for (int i = 0; i < config.fields.length; i++) {
      currentRow.add(_buildFieldWidget(config.fields[i]));
      if ((currentRow.length == columns) || (i == config.fields.length - 1)) {
        rows.add(currentRow);
        currentRow = [];
      }
    }
    return rows;
  }

  Widget _buildFieldWidget(LiveDataFieldConfig field) {
    final param = paramValueMap[field.name];
    final target = targets != null ? targets![field.name] : null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: LiveDataFieldWidget(
          field: field,
          param: param,
          target: target,
          defaultColor: defaultColor,
          machineType: machineType,
        ),
      ),
    );
  }
}
