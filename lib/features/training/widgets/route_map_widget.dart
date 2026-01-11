import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/gpx/gpx_route_tracker.dart';

/// A map widget that displays the GPX route with high transparency
class RouteMapWidget extends StatefulWidget {
  final GpxRouteTracker? gpxTracker;
  final double opacity;
  final bool showMarkers;

  const RouteMapWidget({
    super.key,
    required this.gpxTracker,
    this.opacity = 0.2, // 20% opacity for high transparency
    this.showMarkers = true,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _fitBounds() {
    final gpxTracker = widget.gpxTracker;
    if (gpxTracker == null || !gpxTracker.isLoaded) return;

    final points = gpxTracker.points;
    if (points.isEmpty) return;

    // Convert to LatLng list and create bounds
    final latLngPoints = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final bounds = LatLngBounds.fromPoints(latLngPoints);

    // Fit camera to bounds with padding using MapController
    // Add delay to ensure map is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(20),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gpxTracker == null || !widget.gpxTracker!.isLoaded) {
      return const SizedBox.expand();
    }

    final points = widget.gpxTracker!.points;
    if (points.isEmpty) {
      return const SizedBox.expand();
    }

    // Convert GPX points to LatLng for the map
    final routePoints = points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    // Calculate center point
    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLon = routePoints.first.longitude;
    double maxLon = routePoints.first.longitude;

    for (final point in routePoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLon = point.longitude < minLon ? point.longitude : minLon;
      maxLon = point.longitude > maxLon ? point.longitude : maxLon;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    // Get current position if available
    final currentPosition = widget.gpxTracker!.getCurrentPosition();
    final currentLatLng = currentPosition != null
        ? LatLng(currentPosition.latitude, currentPosition.longitude)
        : null;

    return Opacity(
      opacity: widget.opacity,
      child: IgnorePointer(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 4, // Start zoomed out so fitBounds can work properly
            maxZoom: 18,
            minZoom: 2,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none, // Disable all interactions
            ),
            onMapReady: _fitBounds, // Call fitBounds when map is ready
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.iliuta.ftms',
              maxZoom: 19,
            ),
            // Draw the route as a polyline
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 5.0,
                  color: Colors.red,
                ),
              ],
            ),
            // Draw markers
            if (widget.showMarkers)
              MarkerLayer(
                markers: [
                  // Start position marker
                  Marker(
                    point: routePoints.first,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(200),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  // Current position marker (boat/kayak)
                  if (currentLatLng != null)
                    Marker(
                      point: currentLatLng,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(220),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withAlpha(100),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.kayaking,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
