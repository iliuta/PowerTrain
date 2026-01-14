import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/training/widgets/metronome_visualizer.dart';

void main() {
  group('MetronomeVisualizer', () {
    testWidgets('renders correctly with basic layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 24.0,
              tickCount: 0,
            ),
          ),
        ),
      );

      // Should render a Card
      expect(find.byType(Card), findsOneWidget);

      // Should render a Stack with positioned elements
      expect(find.byType(Stack), findsNWidgets(2)); // One from Scaffold, one from our widget

      // Should render the animated circle
      expect(find.byType(AnimatedPositioned), findsOneWidget);
    });

    testWidgets('circle position changes based on tick count', (WidgetTester tester) async {
      // Test with even tick count (should be at left position)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 50,
              child: MetronomeVisualizer(
                targetCadence: 24.0,
                tickCount: 0, // Even - should be at left
              ),
            ),
          ),
        ),
      );

      // Get the AnimatedPositioned widget
      final animatedPositionedEven = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // With tickCount 0 (even), position should be at left (0.0)
      expect(animatedPositionedEven.left, 0.0);

      // Test with odd tick count (should be at right position)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 50,
              child: MetronomeVisualizer(
                targetCadence: 24.0,
                tickCount: 1, // Odd - should be at right
              ),
            ),
          ),
        ),
      );

      final animatedPositionedOdd = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // With tickCount 1 (odd), position should be at right (calculated based on width)
      // The exact value depends on the track width calculation, but should be > 0
      expect(animatedPositionedOdd.left, greaterThan(0.0));
    });

    testWidgets('animation duration is calculated correctly', (WidgetTester tester) async {
      const targetCadence = 24.0; // strokes per minute

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: targetCadence,
              tickCount: 0,
            ),
          ),
        ),
      );

      final animatedPositioned = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // Duration should be half the metronome period (since it alternates high/low ticks)
      // Period = 60 / targetCadence seconds, half period = 30 / targetCadence seconds
      // In milliseconds: (30 / targetCadence) * 1000 = 30000 / targetCadence
      // For targetCadence = 24: 30000 / 24 = 1250 ms
      final expectedDurationMs = (60 / targetCadence / 2 * 1000).round();
      expect(animatedPositioned.duration.inMilliseconds, expectedDurationMs);
    });

    testWidgets('different cadences produce different animation durations', (WidgetTester tester) async {
      // Test with slower cadence (20 spm)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 20.0,
              tickCount: 0,
            ),
          ),
        ),
      );

      final animatedPositionedSlow = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // Test with faster cadence (30 spm)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 30.0,
              tickCount: 0,
            ),
          ),
        ),
      );

      final animatedPositionedFast = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // Faster cadence should have shorter animation duration
      expect(
        animatedPositionedFast.duration.inMilliseconds,
        lessThan(animatedPositionedSlow.duration.inMilliseconds),
      );
    });

    testWidgets('has proper visual elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 24.0,
              tickCount: 0,
            ),
          ),
        ),
      );

      // Should have multiple Positioned widgets (track bar + 2 end markers + animated circle)
      expect(find.byType(Positioned), findsNWidgets(4)); // track bar + 2 end markers + circle

      // Should have containers for visual elements
      expect(find.byType(Container), findsNWidgets(4)); // track bar + 2 end markers + circle
    });

    testWidgets('uses easeInOut curve for smooth animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 24.0,
              tickCount: 0,
            ),
          ),
        ),
      );

      final animatedPositioned = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      expect(animatedPositioned.curve, Curves.easeInOut);
    });
  });
}