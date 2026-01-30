import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/models/live_data_field_value.dart';
import 'package:ftms/core/widgets/animated_rower_widget.dart';
import 'package:ftms/l10n/app_localizations.dart';

void main() {
  testWidgets('AnimatedRowerWidget displays label and value', (WidgetTester tester) async {
    final displayField = LiveDataFieldConfig(
      name: 'Stroke Rate',
      label: 'Stroke Rate',
      unit: 'spm',
      min: 15,
      max: 40,
      display: 'animatedRower',
      icon: 'rowing',
    );

    final param = LiveDataFieldValue(
      name: 'Stroke Rate',
      value: 24,
      factor: 1,
      unit: 'spm',
      flag: null,
      size: 2,
      signed: false,
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AnimatedRowerWidget(
          displayField: displayField,
          param: param,
          color: Colors.blue,
        ),
      ),
    ));

    expect(find.text('Stroke Rate'), findsOneWidget);
    expect(find.text('24 spm'), findsOneWidget);
  });

  testWidgets('AnimatedRowerWidget animates based on stroke rate', (WidgetTester tester) async {
    final displayField = LiveDataFieldConfig(
      name: 'Stroke Rate',
      label: 'Stroke Rate',
      unit: 'spm',
      min: 15,
      max: 40,
      display: 'animatedRower',
      icon: 'rowing',
    );

    final param = LiveDataFieldValue(
      name: 'Stroke Rate',
      value: 30, // 30 strokes per minute = 2 seconds per stroke
      factor: 1,
      unit: 'spm',
      flag: null,
      size: 2,
      signed: false,
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AnimatedRowerWidget(
          displayField: displayField,
          param: param,
          color: Colors.blue,
        ),
      ),
    ));

    // Wait for animation to progress
    await tester.pump(const Duration(milliseconds: 500));
    
    // Verify the widget renders without errors during animation
    expect(tester.takeException(), isNull);
    
    // Continue animation
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnimatedRowerWidget displays with target interval', (WidgetTester tester) async {
    final displayField = LiveDataFieldConfig(
      name: 'Stroke Rate',
      label: 'Stroke Rate',
      display: 'animatedRower',
      unit: 'spm',
      min: 15,
      max: 40,
      targetRange: 0.08,
    );

    final param = LiveDataFieldValue(
      name: 'Stroke Rate',
      value: 28,
      unit: 'spm',
      factor: 1,
      signed: false,
    );

    final targetInterval = (lower: 26.0, upper: 30.0);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AnimatedRowerWidget(
          displayField: displayField,
          param: param,
          color: Colors.blue,
          targetInterval: targetInterval,
        ),
      ),
    ));

    expect(find.text('Stroke Rate'), findsOneWidget);
    expect(find.text('28 spm'), findsOneWidget);

    // Verify the widget renders without errors (target state is visual)
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnimatedRowerWidget handles null param gracefully', (WidgetTester tester) async {
    final displayField = LiveDataFieldConfig(
      name: 'Stroke Rate',
      label: 'Stroke Rate',
      display: 'animatedRower',
      unit: 'spm',
      min: 15,
      max: 40,
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AnimatedRowerWidget(
          displayField: displayField,
          param: null,
          color: Colors.blue,
        ),
      ),
    ));

    expect(find.text('Stroke Rate'), findsOneWidget);
    // Widget should display without errors when param is null
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnimatedRowerWidget updates animation when stroke rate changes', (WidgetTester tester) async {
    final displayField = LiveDataFieldConfig(
      name: 'Stroke Rate',
      label: 'Stroke Rate',
      unit: 'spm',
      min: 15,
      max: 40,
      display: 'animatedRower',
      icon: 'rowing',
    );

    final param1 = LiveDataFieldValue(
      name: 'Stroke Rate',
      value: 20, // Slower: 3 seconds per stroke
      factor: 1,
      unit: 'spm',
      flag: null,
      size: 2,
      signed: false,
    );

    final param2 = LiveDataFieldValue(
      name: 'Stroke Rate',
      value: 40, // Faster: 1.5 seconds per stroke
      factor: 1,
      unit: 'spm',
      flag: null,
      size: 2,
      signed: false,
    );

    // Build widget with initial stroke rate
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AnimatedRowerWidget(
          key: const ValueKey('rower'),
          displayField: displayField,
          param: param1,
          color: Colors.blue,
        ),
      ),
    ));

    expect(find.text('20 spm'), findsOneWidget);

    // Update with new stroke rate
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AnimatedRowerWidget(
          key: const ValueKey('rower'),
          displayField: displayField,
          param: param2,
          color: Colors.blue,
        ),
      ),
    ));

    expect(find.text('40 spm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
