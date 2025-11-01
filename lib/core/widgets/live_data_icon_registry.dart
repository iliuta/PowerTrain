import 'package:flutter/material.dart';

/// Registry of available FTMS icons for use in config files and widgets.
final Map<String, IconData> liveDataIconRegistry = {
  'heart': Icons.favorite,
  'cadence': Icons.cyclone, // Placeholder for pedal/cadence
  'bike': Icons.pedal_bike,
  'rowing': Icons.rowing,
  'power': Icons.flash_on,
  'distance': Icons.straighten,
  'calories': Icons.local_fire_department,
  'speed': Icons.speed,
  'resistance': Icons.tune
};

/// Utility to select the correct icon for FTMS display fields.
IconData? getLiveDataIcon(String? icon) {
  if (icon == null) return null;
  return liveDataIconRegistry[icon];
}
