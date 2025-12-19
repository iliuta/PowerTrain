import 'gpx_data.dart';

/// Service for tracking position along a GPX route based on distance traveled
class GpxRouteTracker {
  GpxData? _gpxData;
  double _currentDistance = 0;

  /// Whether the route has been loaded successfully
  bool get isLoaded => _gpxData != null;

  /// Total length of the route in meters
  double get totalRouteDistance => _gpxData?.totalDistance ?? 0;

  /// Current traveled distance in meters
  double get currentDistance => _currentDistance;

  /// Number of points in the route
  int get pointCount => _gpxData?.points.length ?? 0;

  /// Get all route points (read-only)
  List<GpxPoint> get points => _gpxData?.points ?? const [];

  /// Load the GPX route from an asset file
  Future<void> loadFromAsset(String assetPath) async {
    _gpxData = await GpxData.loadFromAsset(assetPath);
  }

  /// Load the GPX route from a string content (useful for testing)
  void loadFromString(String gpxContent) {
    _gpxData = GpxData.loadFromString(gpxContent);
  }

  /// Reset the tracker to the start of the route
  void reset() {
    _currentDistance = 0;
  }

  /// Update position based on distance traveled since last update
  /// Returns the current position on the route, or null if route not loaded
  GpxPoint? updatePosition(double distanceDelta) {
    if (!isLoaded || _gpxData!.points.isEmpty) return null;

    _currentDistance += distanceDelta;

    // Handle looping: if we exceed the route length, loop back
    if (_currentDistance > _gpxData!.totalDistance && _gpxData!.totalDistance > 0) {
      _currentDistance = _currentDistance % _gpxData!.totalDistance;
    }

    return getPositionAtDistance(_currentDistance);
  }

  /// Get the position at a specific distance along the route
  GpxPoint? getPositionAtDistance(double distance) {
    if (!isLoaded || _gpxData!.points.isEmpty) return null;

    // Handle distance beyond route length (loop)
    double adjustedDistance = distance;
    if (_gpxData!.totalDistance > 0 && distance > _gpxData!.totalDistance) {
      adjustedDistance = distance % _gpxData!.totalDistance;
    }

    // Find the two points that bracket this distance
    int lowerIndex = 0;
    for (int i = 0; i < _gpxData!.points.length - 1; i++) {
      if (_gpxData!.points[i + 1].cumulativeDistance >= adjustedDistance) {
        lowerIndex = i;
        break;
      }
      lowerIndex = i;
    }

    final p1 = _gpxData!.points[lowerIndex];
    final p2Index = (lowerIndex + 1) % _gpxData!.points.length;
    final p2 = _gpxData!.points[p2Index];

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
    if (!isLoaded || _gpxData!.points.isEmpty) return null;

    final distance = _gpxData!.totalDistance * percentage.clamp(0.0, 1.0);
    return getPositionAtDistance(distance);
  }
}
