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
              isPullPhase: true,
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

    testWidgets('circle position changes based on phase', (WidgetTester tester) async {
      // Test with pull phase (should be moving to right position)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 50,
              child: MetronomeVisualizer(
                targetCadence: 24.0,
                tickCount: 0,
                isPullPhase: true, // Pull - should be moving to right
              ),
            ),
          ),
        ),
      );

      // Get the AnimatedPositioned widget
      final animatedPositionedPull = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // With isPullPhase true, target position should be at right (calculated based on width)
      expect(animatedPositionedPull.left, greaterThan(0.0));

      // Test with recovery phase (should be moving to left position)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 50,
              child: MetronomeVisualizer(
                targetCadence: 24.0,
                tickCount: 1,
                isPullPhase: false, // Recovery - should be moving to left
              ),
            ),
          ),
        ),
      );

      final animatedPositionedRecovery = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // With isPullPhase false, target position should be at left (0.0)
      expect(animatedPositionedRecovery.left, 0.0);
    });

    testWidgets('animation duration reflects pull vs recovery timing', (WidgetTester tester) async {
      const targetCadence = 24.0; // strokes per minute
      final cycleSeconds = 60 / targetCadence;

      // Test pull phase (1/3 of cycle)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: targetCadence,
              tickCount: 0,
              isPullPhase: true,
            ),
          ),
        ),
      );

      final animatedPositionedPull = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // Pull duration should be 1/3 of cycle
      final expectedPullDurationMs = (cycleSeconds / 3 * 1000).round();
      expect(animatedPositionedPull.duration.inMilliseconds, expectedPullDurationMs);

      // Test recovery phase (2/3 of cycle)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: targetCadence,
              tickCount: 1,
              isPullPhase: false,
            ),
          ),
        ),
      );

      final animatedPositionedRecovery = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // Recovery duration should be 2/3 of cycle
      final expectedRecoveryDurationMs = (cycleSeconds * 2 / 3 * 1000).round();
      expect(animatedPositionedRecovery.duration.inMilliseconds, expectedRecoveryDurationMs);
      
      // Recovery should be approximately twice as long as pull
      expect(
        animatedPositionedRecovery.duration.inMilliseconds,
        greaterThan(animatedPositionedPull.duration.inMilliseconds * 1.5),
      );
    });

    testWidgets('different cadences produce different animation durations', (WidgetTester tester) async {
      // Test with slower cadence (20 spm) - pull phase
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 20.0,
              tickCount: 0,
              isPullPhase: true,
            ),
          ),
        ),
      );

      final animatedPositionedSlow = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      // Test with faster cadence (30 spm) - pull phase
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 30.0,
              tickCount: 0,
              isPullPhase: true,
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
              isPullPhase: true,
            ),
          ),
        ),
      );

      // Should have multiple Positioned widgets (track bar + 2 end markers + animated circle)
      expect(find.byType(Positioned), findsNWidgets(4)); // track bar + 2 end markers + circle

      // Should have containers for visual elements
      expect(find.byType(Container), findsNWidgets(4)); // track bar + 2 end markers + circle
    });

    testWidgets('uses different curves for pull and recovery phases', (WidgetTester tester) async {
      // Test pull phase - should use easeOutCubic (explosive)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 24.0,
              tickCount: 0,
              isPullPhase: true,
            ),
          ),
        ),
      );

      final animatedPositionedPull = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      expect(animatedPositionedPull.curve, Curves.easeOutCubic);

      // Test recovery phase - should use easeInOutSine (smooth)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetronomeVisualizer(
              targetCadence: 24.0,
              tickCount: 1,
              isPullPhase: false,
            ),
          ),
        ),
      );

      final animatedPositionedRecovery = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );

      expect(animatedPositionedRecovery.curve, Curves.easeInOutSine);
    });
  });
}