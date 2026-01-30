import 'package:flutter/material.dart';
import '../config/live_data_field_config.dart';
import '../models/live_data_field_value.dart';
import 'animated_rower_widget.dart';
import 'simple_number_widget.dart';
import 'speedometer_widget.dart';

/// Dictionary of available FTMS display widgets for use in config files.
/// Maps display type string to a builder function.
typedef LiveDataFieldWidgetBuilder = Widget Function(
    {required LiveDataFieldConfig displayField, LiveDataFieldValue? param, Color? color, ({double lower, double upper})? targetInterval});

final Map<String, LiveDataFieldWidgetBuilder> liveDataFieldWidgetRegistry = {
  'number': ({required displayField, param, color, targetInterval}) =>
      SimpleNumberWidget(displayField, param!, color),
  'speedometer': ({required displayField, param, color, targetInterval}) => SpeedometerWidget(
        displayField: displayField,
        param: param,
        color: color ?? Colors.blue,
        targetInterval: targetInterval,
      ),
  'animatedRower': ({required displayField, param, color, targetInterval}) => AnimatedRowerWidget(
        displayField: displayField,
        param: param,
        color: color ?? Colors.blue,
        targetInterval: targetInterval,
      ),
};
