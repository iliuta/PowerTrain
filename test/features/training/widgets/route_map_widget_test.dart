import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/gpx/gpx_route_tracker.dart';
import 'package:ftms/features/training/widgets/route_map_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteMapWidget', () {
    testWidgets('shows SizedBox when gpxTracker is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RouteMapWidget(gpxTracker: null),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows SizedBox when gpxTracker is not loaded', (WidgetTester tester) async {
      final tracker = GpxRouteTracker();

      await tester.pumpWidget(
        MaterialApp(
          home: RouteMapWidget(gpxTracker: tracker),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows map when gpxTracker is loaded with points', (WidgetTester tester) async {
      final tracker = GpxRouteTracker();
      const gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
        <ele>35.14</ele>
      </trkpt>
      <trkpt lat="48.8445" lon="2.5113">
        <ele>34.76</ele>
      </trkpt>
      <trkpt lat="48.8452" lon="2.5112">
        <ele>34.76</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
      tracker.loadFromString(gpxContent);

      await tester.pumpWidget(
        MaterialApp(
          home: RouteMapWidget(gpxTracker: tracker),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets('does not show markers when showMarkers is false', (WidgetTester tester) async {
      final tracker = GpxRouteTracker();
      const gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
        <ele>35.14</ele>
      </trkpt>
      <trkpt lat="48.8445" lon="2.5113">
        <ele>34.76</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
      tracker.loadFromString(gpxContent);

      await tester.pumpWidget(
        MaterialApp(
          home: RouteMapWidget(
            gpxTracker: tracker,
            showMarkers: false,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MarkerLayer), findsNothing);
    });

    testWidgets('applies custom opacity', (WidgetTester tester) async {
      final tracker = GpxRouteTracker();
      const gpxContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="48.8438" lon="2.5114">
        <ele>35.14</ele>
      </trkpt>
      <trkpt lat="48.8445" lon="2.5113">
        <ele>34.76</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
      tracker.loadFromString(gpxContent);

      await tester.pumpWidget(
        MaterialApp(
          home: RouteMapWidget(
            gpxTracker: tracker,
            opacity: 0.5,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.5);
    });
  });
}