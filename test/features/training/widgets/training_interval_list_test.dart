import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/widgets/training_interval_list.dart';
import 'package:ftms/l10n/app_localizations.dart';

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      expect(find.text('Main'), findsOneWidget);
      expect(find.text('Cooldown'), findsOneWidget);
      expect(find.text('Warmup'), findsNothing);
      // Interval indices should be shown
      expect(find.text('(2/3)'), findsOneWidget);
      expect(find.text('(3/3)'), findsOneWidget);
      // Current interval should show time left (appears in both progress bar and card)
      expect(find.text('00:100'), findsNWidgets(2));
      // Next interval should show its duration
      expect(find.text('00:30'), findsOneWidget);
      // Cards should be present
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('displays progress bar with elapsed and remaining time', (WidgetTester tester) async {
      final dummyInterval1 = UnitTrainingInterval(title: 'Test', duration: 100, resistanceLevel: 1, targets: {});
      final intervals = <ExpandedUnitTrainingInterval>[
        ExpandedUnitTrainingInterval(duration: 100, title: 'Test', resistanceLevel: 1, targets: {}, originalInterval: dummyInterval1),
      ];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrainingIntervalList(
              intervals: intervals,
              currentInterval: 0,
              intervalElapsed: 30,
              intervalTimeLeft: 70,
              formatMMSS: (s) => '00:${s.toString().padLeft(2, '0')}',
              isDistanceBased: false,
            ),
          ),
        ),
      );
      // Progress bar should show elapsed time
      expect(find.text('00:30'), findsOneWidget);
      // Progress bar should show remaining time (appears in both progress bar and card)
      expect(find.text('00:70'), findsNWidgets(2));
      // LinearProgressIndicator should be present
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('highlights current interval with blue background', (WidgetTester tester) async {
      final dummyInterval1 = UnitTrainingInterval(title: 'Current', duration: 60, resistanceLevel: 1, targets: {});
      final dummyInterval2 = UnitTrainingInterval(title: 'Next', duration: 60, resistanceLevel: 1, targets: {});
      final intervals = <ExpandedUnitTrainingInterval>[
        ExpandedUnitTrainingInterval(duration: 60, title: 'Current', resistanceLevel: 1, targets: {}, originalInterval: dummyInterval1),
        ExpandedUnitTrainingInterval(duration: 60, title: 'Next', resistanceLevel: 1, targets: {}, originalInterval: dummyInterval2),
      ];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrainingIntervalList(
              intervals: intervals,
              currentInterval: 0,
              intervalElapsed: 10,
              intervalTimeLeft: 50,
              formatMMSS: (s) => '00:${s.toString().padLeft(2, '0')}',
              isDistanceBased: false,
            ),
          ),
        ),
      );
      // Current interval should be visible
      expect(find.text('Current'), findsOneWidget);
      // Next interval should be visible
      expect(find.text('Next'), findsOneWidget);
      // Should have 2 cards
      expect(find.byType(Card), findsNWidgets(2));
    });
  });
}
