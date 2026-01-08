import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ftms/core/models/device_types.dart';
import '../config/live_data_field_config.dart';
import '../models/live_data_field_value.dart';
import 'live_data_field_widget_registry.dart';
import 'package:ftms/core/utils/i18n_utils.dart';
import '../../l10n/app_localizations.dart';
import '../services/sound_service.dart';

/// Widget for displaying a single FTMS field.
class LiveDataFieldWidget extends StatefulWidget {
  final LiveDataFieldConfig field;
  final LiveDataFieldValue? param;
  final dynamic target;
  final Color? defaultColor;
  final DeviceType? machineType;

  const LiveDataFieldWidget({
    super.key,
    required this.field,
    required this.param,
    this.target,
    this.defaultColor,
    this.machineType,
  });

  @override
  State<LiveDataFieldWidget> createState() => _LiveDataFieldWidgetState();
}

class _LiveDataFieldWidgetState extends State<LiveDataFieldWidget> {
  late SoundService _soundService;
  bool _wasOutOfRange = false;
  Color? _backgroundColor;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService.instance;
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color? color = widget.defaultColor;
    if (widget.param == null) {
      return Container(
        color: _backgroundColor,
        child: Text('${getFieldLabel(widget.field, Localizations.localeOf(context).languageCode)}: (${AppLocalizations.of(context)!.fieldLabelNotAvailable})', style: const TextStyle(color: Colors.grey)),
      );
    }
    
    final value = widget.param!.value;
    final factor = widget.param!.factor;

    color = _getFieldColor(value, factor, color);

    // Check if out of range
    bool isOutOfRange = false;
    if (widget.target != null && widget.param != null) {
      final targetValue = widget.target is num ? widget.target : num.tryParse(widget.target.toString());
      isOutOfRange = !widget.param!.isWithinTarget(targetValue, widget.field.targetRange);
    }

    // Play sound and flash if just went out of range
    if (isOutOfRange && !_wasOutOfRange) {
      _soundService.playDissapointingBeep();
      _backgroundColor = Colors.red.withValues(alpha: 0.3);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _backgroundColor = null);
      });
    }
    _wasOutOfRange = isOutOfRange;

    // Determine color
    color = _getFieldColor(value, factor, color);

    final widgetBuilder = liveDataFieldWidgetRegistry[widget.field.display];
    if (widgetBuilder != null) {
      // Compute target interval if target is available
      final targetValue = widget.target is num ? widget.target : num.tryParse(widget.target?.toString() ?? '');
      final targetInterval = targetValue != null ? widget.field.computeTargetInterval(targetValue) : null;
      
      return Container(
        color: _backgroundColor,
        child: widgetBuilder(
          displayField: widget.field,
          param: widget.param!,
          color: color,
          targetInterval: targetInterval,
        ),
      );
    }
    return Container(
      color: _backgroundColor,
      child: Text('${getFieldLabel(widget.field, Localizations.localeOf(context).languageCode)}: (${AppLocalizations.of(context)!.fieldLabelUnknownDisplay})', style: const TextStyle(color: Colors.red)),
    );
  }

  Color? _getFieldColor(dynamic value, num factor, Color? color) {
    if (widget.target != null && widget.param != null) {
      final targetValue = widget.target is num ? widget.target : num.tryParse(widget.target.toString());
      if (widget.param!.isWithinTarget(targetValue, widget.field.targetRange)) {
        color = Colors.green[700];
      } else {
        color = Colors.red[700];
      }
    }
    return color;
  }
}
