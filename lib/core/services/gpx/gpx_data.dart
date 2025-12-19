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

/// Contains all GPX file data: points, total distance, and loading functionality
class GpxData {
  final List<GpxPoint> points;
  final double totalDistance;

  const GpxData({
    required this.points,
    required this.totalDistance,
  });

  /// Load GPX data from an asset file
  static Future<GpxData?> loadFromAsset(String assetPath) async {
    try {
      final gpxContent = await rootBundle.loadString(assetPath);
      final data = _parseGpxString(gpxContent);
      if (data != null) {
        logger.i(
            'GPX data loaded: ${data.points.length} points, ${data.totalDistance.toStringAsFixed(1)}m total distance');
      }
      return data;
    } catch (e) {
      logger.e('Failed to load GPX data: $e');
      return null;
    }
  }

  /// Load GPX data from a string content (useful for testing)
  static GpxData? loadFromString(String gpxContent) {
    return _parseGpxString(gpxContent);
  }

  /// Parse GPX XML content and extract track points
  static GpxData? _parseGpxString(String gpxContent) {
    final points = <GpxPoint>[];

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

      points.add(point);
      previousPoint = point;
    }

    if (points.isEmpty) return null;

    return GpxData(
      points: points,
      totalDistance: points.last.cumulativeDistance,
    );
  }

  /// Calculate distance between two coordinates using Haversine formula
  static double _calculateHaversineDistance(
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

  static double _degreesToRadians(double degrees) => degrees * pi / 180;
}