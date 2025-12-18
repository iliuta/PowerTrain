import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/gpx/gpx_route_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GpxPoint', () {
    test('should create GpxPoint with all properties', () {
      const point = GpxPoint(
        latitude: 48.8438,
        longitude: 2.5114,
        elevation: 35.14,
        cumulativeDistance: 100.5,
      );

      expect(point.latitude, 48.8438);
      expect(point.longitude, 2.5114);
      expect(point.elevation, 35.14);
      expect(point.cumulativeDistance, 100.5);
    });

    test('should create GpxPoint without elevation', () {
      const point = GpxPoint(
        latitude: 48.8438,
        longitude: 2.5114,
        cumulativeDistance: 0,
      );

      expect(point.latitude, 48.8438);
      expect(point.longitude, 2.5114);
      expect(point.elevation, isNull);
      expect(point.cumulativeDistance, 0);
    });

    test('toString should include all properties', () {
      const point = GpxPoint(
        latitude: 48.8438,
        longitude: 2.5114,
        elevation: 35.14,
        cumulativeDistance: 100.5,
      );

      final str = point.toString();
      expect(str, contains('48.8438'));
      expect(str, contains('2.5114'));
      expect(str, contains('35.14'));
      expect(str, contains('100.5'));
    });
  });

  group('GpxRouteTracker', () {
    late GpxRouteTracker tracker;

    setUp(() {
      tracker = GpxRouteTracker();
    });

    group('Initial state', () {
      test('should not be loaded initially', () {
        expect(tracker.isLoaded, false);
      });

      test('should have zero total distance initially', () {
        expect(tracker.totalRouteDistance, 0);
      });

      test('should have zero current distance initially', () {
        expect(tracker.currentDistance, 0);
      });

      test('should have zero point count initially', () {
        expect(tracker.pointCount, 0);
      });
    });

    group('GPX parsing with loadFromString', () {
      test('should parse valid GPX content with elevation', () {
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
        <ele>35.14</ele>
      </trkpt>
      <trkpt lat="48.8445" lon="2.5113">
        <ele>35.06</ele>
      </trkpt>
      <trkpt lat="48.8452" lon="2.5112">
        <ele>34.76</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        expect(tracker.isLoaded, true);
        expect(tracker.pointCount, 3);
        expect(tracker.totalRouteDistance, greaterThan(0));
      });

      test('should parse GPX content without elevation', () {
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
      </trkpt>
      <trkpt lat="48.8445" lon="2.5113">
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        expect(tracker.isLoaded, true);
        expect(tracker.pointCount, 2);

        final position = tracker.getPositionAtDistance(0);
        expect(position?.elevation, isNull);
      });

      test('should not be loaded for empty GPX content', () {
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        expect(tracker.isLoaded, false);
        expect(tracker.pointCount, 0);
        expect(tracker.totalRouteDistance, 0);
      });

      test('should handle malformed coordinates gracefully', () {
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="invalid" lon="2.5114">
        <ele>35.14</ele>
      </trkpt>
      <trkpt lat="48.8445" lon="2.5113">
        <ele>35.06</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        // Should only have 1 valid point, but 1 point alone won't be loaded
        expect(tracker.pointCount, 1);
      });
    });

    group('Distance calculation', () {
      test('should calculate cumulative distance correctly', () {
        // Two points approximately 78m apart (0.0007 degrees latitude)
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
        <ele>35.0</ele>
      </trkpt>
      <trkpt lat="48.8445" lon="2.5114">
        <ele>35.0</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        // Distance between lat 48.8438 and 48.8445 at same longitude
        // should be approximately 78 meters (0.0007 degrees * 111km/degree)
        expect(tracker.totalRouteDistance, closeTo(78, 5));
      });

      test('should use Haversine formula for accurate distance', () {
        // Known distance test: 1 degree latitude at equator = ~111km
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="0.0" lon="0.0"><ele>0</ele></trkpt>
      <trkpt lat="1.0" lon="0.0"><ele>0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        // 1 degree latitude = approximately 111,195 meters
        expect(tracker.totalRouteDistance, closeTo(111195, 100));
      });
    });

    group('Position tracking', () {
      late GpxRouteTracker tracker;

      setUp(() {
        tracker = GpxRouteTracker();
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
        <ele>35.0</ele>
      </trkpt>
      <trkpt lat="48.8445" lon="2.5114">
        <ele>36.0</ele>
      </trkpt>
      <trkpt lat="48.8452" lon="2.5114">
        <ele>37.0</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);
      });

      test('should return start position at distance 0', () {
        final position = tracker.getPositionAtDistance(0);

        expect(position, isNotNull);
        expect(position!.latitude, closeTo(48.8438, 0.0001));
        expect(position.longitude, closeTo(2.5114, 0.0001));
        expect(position.elevation, closeTo(35.0, 0.1));
      });

      test('should interpolate position at half distance', () {
        final halfDistance = tracker.totalRouteDistance / 2;
        final position = tracker.getPositionAtDistance(halfDistance);

        expect(position, isNotNull);
        // Should be approximately at the middle point
        expect(position!.latitude, closeTo(48.8445, 0.001));
      });

      test('should return end position at total distance', () {
        final position =
            tracker.getPositionAtDistance(tracker.totalRouteDistance);

        expect(position, isNotNull);
        expect(position!.latitude, closeTo(48.8452, 0.0001));
      });

      test('should loop back when exceeding total distance', () {
        final position =
            tracker.getPositionAtDistance(tracker.totalRouteDistance + 10);

        expect(position, isNotNull);
        // Should be back near the start (looped)
        expect(position!.latitude, closeTo(48.8438, 0.001));
      });

      test('should interpolate elevation correctly', () {
        // First segment: elevation goes from 35.0 to 36.0
        final quarterDistance = tracker.totalRouteDistance / 4;
        final position = tracker.getPositionAtDistance(quarterDistance);

        expect(position, isNotNull);
        expect(position!.elevation, closeTo(35.5, 0.2));
      });

      test('should return null for empty tracker', () {
        final emptyTracker = GpxRouteTracker();
        final position = emptyTracker.getPositionAtDistance(100);
        expect(position, isNull);
      });
    });

    group('updatePosition', () {
      late GpxRouteTracker tracker;

      setUp(() {
        tracker = GpxRouteTracker();
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
        <ele>35.0</ele>
      </trkpt>
      <trkpt lat="48.8452" lon="2.5114">
        <ele>36.0</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);
      });

      test('should return null when not loaded', () {
        final emptyTracker = GpxRouteTracker();
        final position = emptyTracker.updatePosition(10);
        expect(position, isNull);
      });

      test('should update current distance and return position', () {
        expect(tracker.currentDistance, 0);

        final position = tracker.updatePosition(50);

        expect(tracker.currentDistance, 50);
        expect(position, isNotNull);
        expect(position!.latitude, greaterThan(48.8438));
      });

      test('should accumulate distance across multiple updates', () {
        tracker.updatePosition(30);
        tracker.updatePosition(40);
        tracker.updatePosition(50);

        expect(tracker.currentDistance, 120);
      });

      test('should loop when exceeding total distance', () {
        final totalDistance = tracker.totalRouteDistance;

        // Move past the end of the route
        tracker.updatePosition(totalDistance + 20);

        // Should have looped back
        expect(tracker.currentDistance, closeTo(20, 1));
      });

      test('should return position with correct cumulative distance', () {
        final position = tracker.updatePosition(50);
        expect(position!.cumulativeDistance, closeTo(50, 1));
      });
    });

    group('reset', () {
      test('should reset current distance to zero', () {
        tracker = GpxRouteTracker();
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
      <trkpt lat="48.8452" lon="2.5114"><ele>36.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        tracker.updatePosition(100);
        expect(tracker.currentDistance, greaterThan(0));

        tracker.reset();

        expect(tracker.currentDistance, 0);
      });

      test('should allow tracking to continue after reset', () {
        tracker = GpxRouteTracker();
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
      <trkpt lat="48.8452" lon="2.5114"><ele>36.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        tracker.updatePosition(50);
        tracker.reset();

        final position = tracker.updatePosition(25);

        expect(tracker.currentDistance, 25);
        expect(position, isNotNull);
      });
    });

    group('getCurrentPosition', () {
      test('should return position at current distance', () {
        tracker = GpxRouteTracker();
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
      <trkpt lat="48.8452" lon="2.5114"><ele>36.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        tracker.updatePosition(50);

        final position = tracker.getCurrentPosition();
        expect(position, isNotNull);
        expect(position!.cumulativeDistance, closeTo(50, 1));
      });

      test('should return start position when no movement', () {
        tracker = GpxRouteTracker();
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
      <trkpt lat="48.8452" lon="2.5114"><ele>36.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        final position = tracker.getCurrentPosition();
        expect(position, isNotNull);
        expect(position!.latitude, closeTo(48.8438, 0.0001));
      });
    });

    group('getPositionAtPercentage', () {
      setUp(() {
        tracker = GpxRouteTracker();
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
      <trkpt lat="48.8452" lon="2.5114"><ele>36.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);
      });

      test('should return start position at 0%', () {
        final position = tracker.getPositionAtPercentage(0);

        expect(position, isNotNull);
        expect(position!.latitude, closeTo(48.8438, 0.0001));
      });

      test('should return end position at 100%', () {
        final position = tracker.getPositionAtPercentage(1.0);

        expect(position, isNotNull);
        expect(position!.latitude, closeTo(48.8452, 0.0001));
      });

      test('should return middle position at 50%', () {
        final position = tracker.getPositionAtPercentage(0.5);

        expect(position, isNotNull);
        expect(position!.latitude, closeTo(48.8445, 0.001));
      });

      test('should clamp percentage above 1.0', () {
        final position = tracker.getPositionAtPercentage(1.5);

        expect(position, isNotNull);
        // Should be clamped to 100%
        expect(position!.latitude, closeTo(48.8452, 0.0001));
      });

      test('should clamp percentage below 0.0', () {
        final position = tracker.getPositionAtPercentage(-0.5);

        expect(position, isNotNull);
        // Should be clamped to 0%
        expect(position!.latitude, closeTo(48.8438, 0.0001));
      });

      test('should return null for empty tracker', () {
        final emptyTracker = GpxRouteTracker();
        final position = emptyTracker.getPositionAtPercentage(0.5);
        expect(position, isNull);
      });
    });

    group('loadFromAsset', () {
      test('should load GPX file from assets', () async {
        final tracker = GpxRouteTracker();

        // This tests the actual asset loading
        await tracker.loadFromAsset('assets/gpx/rower/vaires.gpx');

        expect(tracker.isLoaded, true);
        expect(tracker.pointCount, greaterThan(0));
        expect(tracker.totalRouteDistance, greaterThan(0));
      });

      test('should handle non-existent asset gracefully', () async {
        final tracker = GpxRouteTracker();

        await tracker.loadFromAsset('non_existent_file.gpx');

        expect(tracker.isLoaded, false);
      });
    });

    group('Edge cases', () {
      test('should handle single point GPX', () {
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        expect(tracker.pointCount, 1);
        expect(tracker.totalRouteDistance, 0);

        final position = tracker.getPositionAtDistance(0);
        expect(position?.latitude, closeTo(48.8438, 0.0001));
      });

      test('should handle very small distances', () {
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
      <trkpt lat="48.8452" lon="2.5114"><ele>36.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        final position = tracker.updatePosition(0.001);
        expect(position, isNotNull);
        expect(tracker.currentDistance, closeTo(0.001, 0.0001));
      });

      test('should handle multiple loops correctly', () {
        final gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114"><ele>35.0</ele></trkpt>
      <trkpt lat="48.8452" lon="2.5114"><ele>36.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
        tracker.loadFromString(gpxContent);

        final totalDistance = tracker.totalRouteDistance;

        // Move 2.5 times around the route
        tracker.updatePosition(totalDistance * 2.5);

        // Should be at 50% of the route
        expect(tracker.currentDistance, closeTo(totalDistance * 0.5, 1));
      });
    });
  });
}
