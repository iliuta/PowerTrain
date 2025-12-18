import 'package:flutter/material.dart';
import '../../../core/services/gpx/gpx_route_tracker.dart';

/// A widget that draws the GPX route as a background with the current position marker
class RouteMapBackground extends StatelessWidget {
  final GpxRouteTracker? gpxTracker;
  final Widget child;
  final double opacity;

  const RouteMapBackground({
    super.key,
    required this.gpxTracker,
    required this.child,
    this.opacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    if (gpxTracker == null || !gpxTracker!.isLoaded) {
      return child;
    }

    return IgnorePointer(
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: CustomPaint(
              painter: _RouteMapPainter(
                gpxTracker: gpxTracker!,
                routeColor: Theme.of(context).colorScheme.primary.withAlpha((255 * opacity).round()),
                positionColor: Theme.of(context).colorScheme.primary,
                trackWidth: 3.0,
                positionRadius: 8.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final GpxRouteTracker gpxTracker;
  final Color routeColor;
  final Color positionColor;
  final double trackWidth;
  final double positionRadius;

  _RouteMapPainter({
    required this.gpxTracker,
    required this.routeColor,
    required this.positionColor,
    this.trackWidth = 2.0,
    this.positionRadius = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = gpxTracker.points;
    if (points.isEmpty) return;

    // Calculate bounds of the route
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLon = double.infinity;
    double maxLon = double.negativeInfinity;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.15;
    final lonPadding = (maxLon - minLon) * 0.15;
    minLat -= latPadding;
    maxLat += latPadding;
    minLon -= lonPadding;
    maxLon += lonPadding;

    // Create scaling functions to convert lat/lon to screen coordinates
    // Note: latitude increases going up, but screen y increases going down
    final latRange = maxLat - minLat;
    final lonRange = maxLon - minLon;

    // Maintain aspect ratio
    final screenAspect = size.width / size.height;
    final routeAspect = lonRange / latRange;

    double scaleX, scaleY;
    double offsetX = 0, offsetY = 0;

    if (routeAspect > screenAspect) {
      // Route is wider than screen, fit to width
      scaleX = size.width / lonRange;
      scaleY = scaleX;
      offsetY = (size.height - latRange * scaleY) / 2;
    } else {
      // Route is taller than screen, fit to height
      scaleY = size.height / latRange;
      scaleX = scaleY;
      offsetX = (size.width - lonRange * scaleX) / 2;
    }

    Offset toScreen(double lat, double lon) {
      final x = (lon - minLon) * scaleX + offsetX;
      final y = (maxLat - lat) * scaleY + offsetY; // Flip y-axis
      return Offset(x, y);
    }

    // Draw the route as a path
    final routePaint = Paint()
      ..color = routeColor
      ..strokeWidth = trackWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool firstPoint = true;
    for (final point in points) {
      final screenPos = toScreen(point.latitude, point.longitude);
      if (firstPoint) {
        path.moveTo(screenPos.dx, screenPos.dy);
        firstPoint = false;
      } else {
        path.lineTo(screenPos.dx, screenPos.dy);
      }
    }
    canvas.drawPath(path, routePaint);

    // Draw current position marker
    final currentPosition = gpxTracker.getCurrentPosition();
    if (currentPosition != null) {
      final positionOffset = toScreen(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Draw outer glow/halo
      final haloPaint = Paint()
        ..color = positionColor.withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(positionOffset, positionRadius * 1.8, haloPaint);

      // Draw position dot
      final positionPaint = Paint()
        ..color = positionColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(positionOffset, positionRadius, positionPaint);

      // Draw inner white dot
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(positionOffset, positionRadius * 0.4, innerPaint);
    }

    // Draw start marker (small green circle)
    final startPoint = points.first;
    final startOffset = toScreen(startPoint.latitude, startPoint.longitude);
    final startPaint = Paint()
      ..color = Colors.green.withAlpha(180)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startOffset, positionRadius * 0.6, startPaint);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) {
    return oldDelegate.gpxTracker.currentDistance != gpxTracker.currentDistance;
  }
}
