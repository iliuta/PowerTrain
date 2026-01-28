import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/ftms/widgets/duration_distance_picker.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('DurationPicker', () {
    testWidgets('displays current duration', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        DurationPicker(
          durationMinutes: 30,
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('displays label when provided', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        DurationPicker(
          durationMinutes: 30,
          label: 'Duration:',
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(find.text('Duration:'), findsOneWidget);
    });

    testWidgets('calls onChanged when increment button tapped', (WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        DurationPicker(
          durationMinutes: 30,
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.add));
      expect(changedValue, 31);
    });

    testWidgets('calls onChanged when decrement button tapped', (WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        DurationPicker(
          durationMinutes: 30,
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.remove));
      expect(changedValue, 29);
    });

    testWidgets('decrement button disabled at minimum', (WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        DurationPicker(
          durationMinutes: 1,
          minMinutes: 1,
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.remove));
      expect(changedValue, isNull); // Should not be called
    });

    testWidgets('increment button disabled at maximum', (WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        DurationPicker(
          durationMinutes: 120,
          maxMinutes: 120,
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.add));
      expect(changedValue, isNull); // Should not be called
    });
  });

  group('DistancePicker', () {
    testWidgets('displays current distance in km', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        DistancePicker(
          distanceMeters: 5000,
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(find.text('5.0 km'), findsOneWidget);
    });

    testWidgets('displays label when provided', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        DistancePicker(
          distanceMeters: 5000,
          label: 'Distance:',
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(find.text('Distance:'), findsOneWidget);
    });

    testWidgets('increments by specified increment', (WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        DistancePicker(
          distanceMeters: 5000,
          incrementMeters: 250,
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.add));
      expect(changedValue, 5250);
    });

    testWidgets('decrements by specified increment', (WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        DistancePicker(
          distanceMeters: 5000,
          incrementMeters: 1000,
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.remove));
      expect(changedValue, 4000);
    });

    testWidgets('decrement disabled when at increment value', (WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        DistancePicker(
          distanceMeters: 1000,
          incrementMeters: 1000,
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.remove));
      expect(changedValue, isNull); // Should not be called
    });
  });

  group('DurationDistancePicker', () {
    testWidgets('shows time picker when not distance based', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        DurationDistancePicker(
          isDistanceBased: false,
          durationMinutes: 30,
          distanceMeters: 5000,
          distanceIncrement: 1000,
          onModeChanged: (_) {},
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('Duration:'), findsOneWidget);
    });

    testWidgets('shows distance picker when distance based', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        DurationDistancePicker(
          isDistanceBased: true,
          durationMinutes: 30,
          distanceMeters: 5000,
          distanceIncrement: 1000,
          onModeChanged: (_) {},
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(find.text('5.0 km'), findsOneWidget);
      expect(find.text('Distance:'), findsAtLeast(1));
    });

    testWidgets('toggle switch calls onModeChanged', (WidgetTester tester) async {
      bool? newMode;
      await tester.pumpWidget(createTestWidget(
        DurationDistancePicker(
          isDistanceBased: false,
          durationMinutes: 30,
          distanceMeters: 5000,
          distanceIncrement: 1000,
          onModeChanged: (value) => newMode = value,
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byType(Switch));
      expect(newMode, true);
    });

    testWidgets('duration change calls onDurationChanged', (WidgetTester tester) async {
      int? newDuration;
      await tester.pumpWidget(createTestWidget(
        DurationDistancePicker(
          isDistanceBased: false,
          durationMinutes: 30,
          distanceMeters: 5000,
          distanceIncrement: 1000,
          onModeChanged: (_) {},
          onDurationChanged: (value) => newDuration = value,
          onDistanceChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.add));
      expect(newDuration, 31);
    });

    testWidgets('distance change calls onDistanceChanged', (WidgetTester tester) async {
      int? newDistance;
      await tester.pumpWidget(createTestWidget(
        DurationDistancePicker(
          isDistanceBased: true,
          durationMinutes: 30,
          distanceMeters: 5000,
          distanceIncrement: 1000,
          onModeChanged: (_) {},
          onDurationChanged: (_) {},
          onDistanceChanged: (value) => newDistance = value,
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byIcon(Icons.add));
      expect(newDistance, 6000);
    });
  });
}
