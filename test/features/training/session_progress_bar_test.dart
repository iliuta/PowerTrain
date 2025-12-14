import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/widgets/session_progress_bar.dart';
import 'package:ftms/features/training/widgets/training_session_chart.dart';

void main() {
  testWidgets('SessionProgressBar displays chart and formatted time', (WidgetTester tester) async {
    // Create dummy original intervals for testing
    final warmupInterval = UnitTrainingInterval(duration: 60, title: 'Warmup');
    final workInterval = UnitTrainingInterval(duration: 120, title: 'Work');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionProgressBar(
            progress: 0.5,
            timeLeft: 90,
            elapsed: 90,
            formatTime: (s) => s == 90 ? '01:30' : '01:30',
            intervals: [
              ExpandedUnitTrainingInterval(
                duration: 60,
                title: 'Warmup',
                targets: {'Instantaneous Power': 100},
                originalInterval: warmupInterval,
              ),
              ExpandedUnitTrainingInterval(
                duration: 120,
                title: 'Work',
                targets: {'Instantaneous Power': 200},
                originalInterval: workInterval,
              ),
            ],
            machineType: DeviceType.indoorBike,
          ),
        ),
      ),
    );
    expect(find.byType(TrainingSessionChart), findsOneWidget);
    expect(find.text('01:30'), findsNWidgets(2)); // Elapsed and timeLeft
  });
}