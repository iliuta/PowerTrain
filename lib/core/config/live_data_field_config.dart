/// This class describes the configuration for live data fields in the app:
/// their name, their label to be used in the UI, how they should be displayed,
class LiveDataFieldConfig {
  /// The name of the field, corresponding to FTMS parameter names
  /// as specified in the FTMS library.
  /// Examples include 'Instantaneous Power', 'Heart Rate', etc.
  final String name;
  /// The label to be displayed in the UI for this field.
  final String label;
  /// Localized labels keyed by language code (e.g., 'en', 'fr', 'de').
  /// If provided, this should be used for display instead of [label].
  final Map<String, String>? labelI18n;
  /// The display type for this field, such as 'number', 'speedometer', etc.
  /// to be taken from widgets/frms_display_widget_registry.dart
  final String display;
  /// Optional formatter for the field value, used to format the value for display.
  /// For example, 'rowerPaceFormatter' for rower pace formatting.
  final String? formatter;
  /// The unit of measurement for this field, such as 'km/h', 'rpm', etc.
  final String unit;
  /// Optional minimum value for the field, used for validation or display purposes.
  final num? min;
  /// Optional maximum value for the field, used for validation or display purposes.
  final num? max;
  /// Optional icon name for the field, used in the UI to represent the field visually.
  /// the values are defined in ftmsIconRegistry
  final String? icon;
  /// Optional sample period in seconds for the field. Useful for fields that
  /// require averaging over a period of time, such as power.
  final int? samplePeriodSeconds;
  /// Whether this field is available as a target in training sessions.
  /// When true, this field can be used to set target values during workouts.
  final bool availableAsTarget;
  /// Optional reference to the corresponding user setting key.
  /// This links the field to a specific user setting for training purposes.
  /// For example, 'rowingFtp' for rowing FTP or 'cyclingFtp' for cycling FTP.
  final String? userSetting;
  /// The percentage range to use when calculating isWithinRange for target values.
  /// Represents the tolerance as a decimal (e.g., 0.1 for 10%, 0.05 for 5%).
  /// Defaults to 0.1 (10%) if not specified.
  final double targetRange;
  /// Whether this field should be treated as cumulative during training sessions.
  /// When true, the field value will be maintained as a running total that only increases,
  /// even if the device disconnects and reconnects (which might reset the device's counter).
  /// This is particularly useful for fields like calories, distance, and duration.
  final bool isCumulative;

  LiveDataFieldConfig({
    required this.name,
    required this.label,
    this.labelI18n,
    required this.display,
    this.formatter,
    required this.unit,
    this.min,
    this.max,
    this.icon,
    this.samplePeriodSeconds,
    this.availableAsTarget = false,
    this.userSetting,
    this.targetRange = 0.1,
    this.isCumulative = false,
  });
  /// Computes the target interval range for a given target value.
  /// Returns a record with (lower, upper) bounds based on the targetRange percentage.
  /// 
  /// For fields where min > max (like pace values), the calculation is adjusted
  /// to ensure the interval makes sense within the field's constraints.
  /// 
  /// [target] The target value to compute the interval around
  /// Returns a record with (lower, upper) bounds, or null if target is null
  ({double lower, double upper})? computeTargetInterval(num? target) {
    if (target == null) return null;
    
    final targetValue = target.toDouble();
    final range = targetValue * targetRange;
    
    // Calculate initial bounds
    var lower = targetValue - range.abs();
    var upper = targetValue + range.abs();
    
    // Apply bounds if they exist
    if (min != null && max != null) {
      if (min! <= max!) {
        // Normal fields where min <= max
        lower = lower.clamp(min!.toDouble(), double.infinity);
        upper = upper.clamp(double.negativeInfinity, max!.toDouble());
      } else {
        // Inverted fields where min > max (e.g., pace values)
        // max is the lower constraint (best/fastest value), min is the upper constraint (worst/slowest value)
        lower = lower.clamp(max!.toDouble(), double.infinity);
        upper = upper.clamp(double.negativeInfinity, min!.toDouble());
      }
    } else {
      // Apply individual bounds if only one exists
      if (min != null) lower = lower.clamp(min!.toDouble(), double.infinity);
      if (max != null) upper = upper.clamp(double.negativeInfinity, max!.toDouble());
    }
    
    return (lower: lower, upper: upper);
  }

  factory LiveDataFieldConfig.fromJson(Map<String, dynamic> json) {
    return LiveDataFieldConfig(
      name: json['name'] as String,
      label: json['label'] as String,
      labelI18n: json['labelI18n'] != null 
        ? Map<String, String>.from(json['labelI18n'] as Map)
        : null,
      display: json['display'] as String? ?? 'number',
      formatter: json['formatter'] as String?,
      unit: json['unit'] as String? ?? '',
      min: json['min'] as num?,
      max: json['max'] as num?,
      icon: json['icon'] as String?,
      samplePeriodSeconds: json['samplePeriodSeconds'] as int?,
      availableAsTarget: json['availableAsTarget'] as bool? ?? false,
      userSetting: json['userSetting'] as String?,
      targetRange: json['targetRange'] as double? ?? 0.1,
      isCumulative: json['isCumulative'] as bool? ?? false,
    );
  }
}