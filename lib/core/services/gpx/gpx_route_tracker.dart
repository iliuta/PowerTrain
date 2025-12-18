import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../../utils/logger.dart';

/// Represents a single point on the GPX route
class GpxPoint {
  final double latitude;
  final double longitude;
  final double? elevation;
  
  /// Cumulative distance from start of route in meters
  final double cumulativeDistance;

  const GpxPoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
    required this.cumulativeDistance,
  });

  @override
  String toString() =>
      'GpxPoint(lat: $latitude, lon: $longitude, ele: $elevation, dist: ${cumulativeDistance.toStringAsFixed(1)}m)';
}

/// Service for tracking position along a GPX route based on distance traveled
class GpxRouteTracker {
  final List<GpxPoint> _points = [];
  double _totalRouteDistance = 0;
  double _currentDistance = 0;
  bool _isLoaded = false;

  /// Whether the route has been loaded successfully
  bool get isLoaded => _isLoaded;

  /// Total length of the route in meters
  double get totalRouteDistance => _totalRouteDistance;

  /// Current traveled distance in meters
  double get currentDistance => _currentDistance;

  /// Number of points in the route
  int get pointCount => _points.length;

  /// Get all route points (read-only)
  List<GpxPoint> get points => List.unmodifiable(_points);

  /// Load the GPX route from an asset file
  Future<void> loadFromAsset(String assetPath) async {
    try {
      final gpxContent = await rootBundle.loadString(assetPath);
      loadFromString(gpxContent);
      logger.i(
          'GPX route loaded: ${_points.length} points, ${_totalRouteDistance.toStringAsFixed(1)}m total distance');
    } catch (e) {
      logger.e('Failed to load GPX route: $e');
      _isLoaded = false;
    }
  }

  /// Load the GPX route from a string content (useful for testing)
  void loadFromString(String gpxContent) {
    _parseGpx(gpxContent);
    _isLoaded = _points.isNotEmpty;
  }

  /// Parse GPX XML content and extract track points
  void _parseGpx(String gpxContent) {
    _points.clear();
    _totalRouteDistance = 0;

    // Simple XML parsing for GPX track points
    final trkptRegex = RegExp(
        r'<trkpt\s+lat="([^"]+)"\s+lon="([^"]+)"[^>]*>([^<]*(?:<(?!\/trkpt)[^>]*>[^<]*)*)<\/trkpt>',
        multiLine: true,
        dotAll: true);
    
    final eleRegex = RegExp(r'<ele>([^<]+)<\/ele>');

    double cumulativeDistance = 0;
    GpxPoint? previousPoint;

    for (final match in trkptRegex.allMatches(gpxContent)) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lon = double.tryParse(match.group(2) ?? '');
      final content = match.group(3) ?? '';

      if (lat == null || lon == null) continue;

      double? elevation;
      final eleMatch = eleRegex.firstMatch(content);
      if (eleMatch != null) {
        elevation = double.tryParse(eleMatch.group(1) ?? '');
      }

      // Calculate distance from previous point
      if (previousPoint != null) {
        final distance = _calculateHaversineDistance(
          previousPoint.latitude,
          previousPoint.longitude,
          lat,
          lon,
        );
        cumulativeDistance += distance;
      }

      final point = GpxPoint(
        latitude: lat,
        longitude: lon,
        elevation: elevation,
        cumulativeDistance: cumulativeDistance,
      );

      _points.add(point);
      previousPoint = point;
    }

    if (_points.isNotEmpty) {
      _totalRouteDistance = _points.last.cumulativeDistance;
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  /// Reset the tracker to the start of the route
  void reset() {
    _currentDistance = 0;
  }

  /// Update position based on distance traveled since last update
  /// Returns the current position on the route, or null if route not loaded
  GpxPoint? updatePosition(double distanceDelta) {
    if (!_isLoaded || _points.isEmpty) return null;

    _currentDistance += distanceDelta;

    // Handle looping: if we exceed the route length, loop back
    if (_currentDistance > _totalRouteDistance && _totalRouteDistance > 0) {
      _currentDistance = _currentDistance % _totalRouteDistance;
    }

    return getPositionAtDistance(_currentDistance);
  }

  /// Get the position at a specific distance along the route
  GpxPoint? getPositionAtDistance(double distance) {
    if (!_isLoaded || _points.isEmpty) return null;

    // Handle distance beyond route length (loop)
    double adjustedDistance = distance;
    if (_totalRouteDistance > 0 && distance > _totalRouteDistance) {
      adjustedDistance = distance % _totalRouteDistance;
    }

    // Find the two points that bracket this distance
    int lowerIndex = 0;
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i + 1].cumulativeDistance >= adjustedDistance) {
        lowerIndex = i;
        break;
      }
      lowerIndex = i;
    }

    final p1 = _points[lowerIndex];
    final p2Index = (lowerIndex + 1) % _points.length;
    final p2 = _points[p2Index];

    // Interpolate between the two points
    final segmentLength = p2.cumulativeDistance - p1.cumulativeDistance;
    double fraction = 0;
    if (segmentLength > 0) {
      fraction = (adjustedDistance - p1.cumulativeDistance) / segmentLength;
      fraction = fraction.clamp(0.0, 1.0);
    }

    final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
    final lon = p1.longitude + (p2.longitude - p1.longitude) * fraction;
    double? elevation;
    if (p1.elevation != null && p2.elevation != null) {
      elevation = p1.elevation! + (p2.elevation! - p1.elevation!) * fraction;
    }

    return GpxPoint(
      latitude: lat,
      longitude: lon,
      elevation: elevation,
      cumulativeDistance: adjustedDistance,
    );
  }

  /// Get the current position based on total distance traveled
  GpxPoint? getCurrentPosition() {
    return getPositionAtDistance(_currentDistance);
  }

  /// Get position at a specific percentage of the route (0.0 to 1.0)
  GpxPoint? getPositionAtPercentage(double percentage) {
    if (!_isLoaded || _points.isEmpty) return null;
    
    final distance = _totalRouteDistance * percentage.clamp(0.0, 1.0);
    return getPositionAtDistance(distance);
  }
}
