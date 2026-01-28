import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// Callback for duration changes
typedef DurationChangedCallback = void Function(int minutes);

/// Callback for distance changes
typedef DistanceChangedCallback = void Function(int meters);

/// A reusable widget for picking duration in minutes with +/- buttons
class DurationPicker extends StatelessWidget {
  /// Current duration in minutes
  final int durationMinutes;

  /// Minimum duration in minutes
  final int minMinutes;

  /// Maximum duration in minutes
  final int maxMinutes;

  /// Callback when duration changes
  final DurationChangedCallback onChanged;

  /// Optional label to display above the picker
  final String? label;

  const DurationPicker({
    super.key,
    required this.durationMinutes,
    required this.onChanged,
    this.minMinutes = 1,
    this.maxMinutes = 120,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (label != null) ...[
          Text(label!),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: durationMinutes > minMinutes
                  ? () => onChanged(durationMinutes - 1)
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$durationMinutes min',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: durationMinutes < maxMinutes
                  ? () => onChanged(durationMinutes + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// A reusable widget for picking distance in meters with +/- buttons
class DistancePicker extends StatelessWidget {
  /// Current distance in meters
  final int distanceMeters;

  /// Distance increment in meters
  final int incrementMeters;

  /// Minimum distance in meters
  final int minMeters;

  /// Maximum distance in meters
  final int maxMeters;

  /// Callback when distance changes
  final DistanceChangedCallback onChanged;

  /// Optional label to display above the picker
  final String? label;

  const DistancePicker({
    super.key,
    required this.distanceMeters,
    required this.onChanged,
    this.incrementMeters = 1000,
    this.minMeters = 250,
    this.maxMeters = 50000,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (label != null) ...[
          Text(label!),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: distanceMeters > incrementMeters
                  ? () => onChanged(distanceMeters - incrementMeters)
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(distanceMeters / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: distanceMeters < maxMeters
                  ? () => onChanged(distanceMeters + incrementMeters)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// A combined widget that switches between duration and distance pickers
class DurationDistancePicker extends StatelessWidget {
  /// Whether to show distance (true) or duration (false)
  final bool isDistanceBased;

  /// Current duration in minutes
  final int durationMinutes;

  /// Current distance in meters
  final int distanceMeters;

  /// Distance increment in meters
  final int distanceIncrement;

  /// Callback when distance/duration mode changes
  final ValueChanged<bool> onModeChanged;

  /// Callback when duration changes
  final DurationChangedCallback onDurationChanged;

  /// Callback when distance changes
  final DistanceChangedCallback onDistanceChanged;

  /// Minimum duration in minutes
  final int minMinutes;

  /// Maximum duration in minutes
  final int maxMinutes;

  const DurationDistancePicker({
    super.key,
    required this.isDistanceBased,
    required this.durationMinutes,
    required this.distanceMeters,
    required this.distanceIncrement,
    required this.onModeChanged,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    this.minMinutes = 1,
    this.maxMinutes = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle between Time and Distance
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)!.time),
            Switch(
              value: isDistanceBased,
              onChanged: onModeChanged,
            ),
            Text(AppLocalizations.of(context)!.distance),
          ],
        ),
        const SizedBox(height: 16),
        Text(isDistanceBased ? 'Distance:' : 'Duration:'),
        const SizedBox(height: 8),
        if (isDistanceBased)
          DistancePicker(
            distanceMeters: distanceMeters,
            incrementMeters: distanceIncrement,
            onChanged: onDistanceChanged,
          )
        else
          DurationPicker(
            durationMinutes: durationMinutes,
            minMinutes: minMinutes,
            maxMinutes: maxMinutes,
            onChanged: onDurationChanged,
          ),
      ],
    );
  }
}
