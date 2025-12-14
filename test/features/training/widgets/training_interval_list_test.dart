import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/widgets/training_interval_list.dart';

void main() {
  group('TrainingIntervalList', () {
    testWidgets('displays intervals and highlights current', (WidgetTester tester) async {
      final dummyInterval1 = UnitTrainingInterval(title: 'Warmup', duration: 60, resistanceLevel: 1, targets: {'power': 100});
      final dummyInterval2 = UnitTrainingInterval(title: 'Main', duration: 120, resistanceLevel: 2, targets: {'power': 200});
      final dummyInterval3 = UnitTrainingInterval(title: 'Cooldown', duration: 30, resistanceLevel: 1, targets: {'power': 80});
      final intervals = <ExpandedUnitTrainingInterval>[
        ExpandedUnitTrainingInterval(duration: 60, title: 'Warmup', resistanceLevel: 1, targets: {'power': 100}, originalInterval: dummyInterval1),
        ExpandedUnitTrainingInterval(duration: 120, title: 'Main', resistanceLevel: 2, targets: {'power': 200}, originalInterval: dummyInterval2),
        ExpandedUnitTrainingInterval(duration: 30, title: 'Cooldown', resistanceLevel: 1, targets: {'power': 80}, originalInterval: dummyInterval3),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingIntervalList(
              intervals: intervals,
              currentInterval: 1,
              intervalElapsed: 20,
              intervalTimeLeft: 100,
              formatMMSS: (s) => '00:${s.toString().padLeft(2, '0')}',
              isDistanceBased: false,
            ),
          ),
        ),
      );
      // Only 2 intervals should be shown (current and next)
      expect(find.text('Main (2/3)'), findsOneWidget);
      expect(find.text('Cooldown (3/3)'), findsOneWidget);
      expect(find.text('Warmup'), findsNothing);
      // Current interval should show time left in bold
      expect(find.text('00:100'), findsOneWidget);
      // Next interval should show its duration
      expect(find.text('00:30'), findsOneWidget);
      // Targets should be displayed
      expect(find.textContaining('Targets:'), findsNWidgets(2));
    });
  });
}
