import 'package:flutter/material.dart';
import '../../../core/services/gpx/gpx_data.dart';
import '../../../core/services/gpx/gpx_route_tracker.dart';
import '../../../l10n/app_localizations.dart';
import '../../training/widgets/route_map_widget.dart';

/// A preview widget for a GPX file showing a small map with title and distance
class GpxMapPreviewWidget extends StatefulWidget {
  final GpxData info;
  final bool isSelected;
  final VoidCallback onTap;

  const GpxMapPreviewWidget({
    super.key,
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<GpxMapPreviewWidget> createState() => _GpxMapPreviewWidgetState();
}

class _GpxMapPreviewWidgetState extends State<GpxMapPreviewWidget> {
  GpxRouteTracker? _tracker;

  @override
  void initState() {
    super.initState();
    _loadTracker();
  }

  Future<void> _loadTracker() async {
    final tracker = GpxRouteTracker();
    await tracker.loadFromAsset(widget.info.assetPath!);
    setState(() {
      _tracker = tracker;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 100,
        height: 75,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            width: widget.isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              // Map
              RouteMapWidget(
                gpxTracker: _tracker,
                opacity: 1.0, // Full opacity for preview
                showMarkers: false,
              ),
              // Overlay with title and distance
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(180),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.info.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${(widget.info.totalDistance / 1000).toStringAsFixed(1)} ${AppLocalizations.of(context)!.kilometers}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}