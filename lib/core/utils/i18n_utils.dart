import 'package:ftms/core/config/live_data_field_config.dart';

/// Utility to get the localized label from a field configuration
String getFieldLabel(LiveDataFieldConfig field, String localeCode) {
  if (field.labelI18n != null && field.labelI18n!.containsKey(localeCode)) {
    return field.labelI18n![localeCode]!;
  }
  // Fallback to the field label if no i18n version exists
  return field.label;
}
