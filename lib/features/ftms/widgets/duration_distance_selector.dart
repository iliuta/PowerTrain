import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// Reusable widget for selecting duration or distance with time/distance toggle
class DurationDistanceSelector extends StatefulWidget {
  final bool isDistanceBased;
  final int durationMinutes;
  final int distanceMeters;
  final int distanceIncrement;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onDistanceChanged;
  final ValueChanged<bool> onModeChanged;

  const DurationDistanceSelector({
    super.key,
    required this.isDistanceBased,
    required this.durationMinutes,
    required this.distanceMeters,
    required this.distanceIncrement,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    required this.onModeChanged,
  });

  @override
  State<DurationDistanceSelector> createState() =>
      _DurationDistanceSelectorState();
}

class _DurationDistanceSelectorState extends State<DurationDistanceSelector> {
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
              value: widget.isDistanceBased,
              onChanged: widget.onModeChanged,
            ),
            Text(AppLocalizations.of(context)!.distance),
          ],
        ),
        const SizedBox(height: 16),
        Text(widget.isDistanceBased ? 'Distance:' : 'Duration:'),
        const SizedBox(height: 8),
        if (widget.isDistanceBased)
          _buildDistanceSelector()
        else
          _buildDurationSelector(),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: widget.durationMinutes > 1
              ? () => widget.onDurationChanged(widget.durationMinutes - 1)
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${widget.durationMinutes} min',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: widget.durationMinutes < 120
              ? () => widget.onDurationChanged(widget.durationMinutes + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildDistanceSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: widget.distanceMeters > widget.distanceIncrement
              ? () => widget.onDistanceChanged(
                  widget.distanceMeters - widget.distanceIncrement)
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${(widget.distanceMeters / 1000).toStringAsFixed(1)} km',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: widget.distanceMeters < 50000
              ? () => widget.onDistanceChanged(
                  widget.distanceMeters + widget.distanceIncrement)
              : null,
        ),
      ],
    );
  }
}
