import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/widgets/edit_target_fields_widget.dart';
import 'package:ftms/l10n/app_localizations.dart';

void main() {
  group('EditTargetFieldsWidget', () {
    late UserSettings userSettings;
    late LiveDataDisplayConfig config;
    late Map<String, dynamic> targets;
    late List<String> changedFields;

    setUp(() {
      userSettings = UserSettings(
        cyclingFtp: 200,
        rowingFtp: '2:00/500m',
        developerMode: false,
        soundEnabled: true,
      );

      config = LiveDataDisplayConfig(
        deviceType: DeviceType.rower,
        fields: [
          LiveDataFieldConfig(
            name: 'Power',
            label: 'Power',
            display: 'Power',
            unit: 'W',
            availableAsTarget: true,
            userSetting: 'cyclingFtp',
            formatter: 'intFormatter', // Add formatter to test formatting
          ),
          LiveDataFieldConfig(
            name: 'Heart Rate',
            label: 'HR',
            display: 'Heart Rate',
            unit: 'bpm',
            availableAsTarget: true,
            userSetting: null, // Not percentage-capable
            formatter: null,
          ),
          LiveDataFieldConfig(
            name: 'Cadence',
            label: 'Cadence',
            display: 'Cadence',
            unit: 'rpm',
            availableAsTarget: false, // Not available as target
            userSetting: null,
            formatter: null,
          ),
        ],
      );

      targets = {};
      changedFields = [];
    });

    testWidgets('displays target fields for available targets', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.rower,
              userSettings: userSettings,
              config: config,
              targets: targets,
              onTargetChanged: (name, value) {
                changedFields.add(name);
              },
            ),
          ),
        ),
      );

      // Should show Power and Heart Rate fields, but not Cadence
      expect(find.text('Power:'), findsOneWidget);
      expect(find.text('HR:'), findsOneWidget);
      expect(find.text('Cadence:'), findsNothing);
    });

    testWidgets('percentage input for fields with userSetting', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.rower,
              userSettings: userSettings,
              config: config,
              targets: {'Power': '80%'},
              onTargetChanged: (name, value) {
                changedFields.add('$name:$value');
              },
            ),
          ),
        ),
      );

      // Power field should have percentage input
      expect(find.byType(TextFormField), findsNWidgets(2)); // Power and HR
      expect(find.text('%'), findsOneWidget); // Suffix for percentage

      // Enter percentage for Power
      await tester.enterText(find.byType(TextFormField).first, '85');
      await tester.pump();

      expect(changedFields, contains('Power:85%'));
    });

    testWidgets('number input for fields without userSetting', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.rower,
              userSettings: userSettings,
              config: config,
              targets: {'Heart Rate': 150},
              onTargetChanged: (name, value) {
                changedFields.add('$name:$value');
              },
            ),
          ),
        ),
      );

      // Heart Rate field should have number input
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      // Enter value for Heart Rate (second field)
      await tester.enterText(textFields.at(1), '160');
      await tester.pump();

      expect(changedFields, contains('Heart Rate:160'));
    });

    testWidgets('shows absolute value preview for percentage inputs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.indoorBike, // Use bike for cyclingFtp
              userSettings: userSettings,
              config: config,
              targets: {'Power': '80%'},
              onTargetChanged: (name, value) {},
            ),
          ),
        ),
      );

      // Should show calculated absolute value (80% of 200 FTP = 160)
      expect(find.text('≈ 160'), findsOneWidget);
    });

    testWidgets('clears target when input is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.rower,
              userSettings: userSettings,
              config: config,
              targets: {'Power': '80%'},
              onTargetChanged: (name, value) {
                changedFields.add('$name:${value ?? "null"}');
              },
            ),
          ),
        ),
      );

      // Clear the Power field
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.pump();

      expect(changedFields, contains('Power:null'));
    });

    testWidgets('clears target when clear button is pressed for percentage field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.rower,
              userSettings: userSettings,
              config: config,
              targets: {'Power': '80%'},
              onTargetChanged: (name, value) {
                changedFields.add('$name:${value ?? "null"}');
              },
            ),
          ),
        ),
      );

      // Find and tap the clear button
      expect(find.byIcon(Icons.clear), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Should call onTargetChanged with null
      expect(changedFields, contains('Power:null'));

      // TextFormField should be empty
      final textField = find.byType(TextFormField).first;
      expect(find.descendant(of: textField, matching: find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == '',
      )), findsOneWidget);
    });

    testWidgets('clears target when clear button is pressed for numeric field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.rower,
              userSettings: userSettings,
              config: config,
              targets: {'Heart Rate': 150},
              onTargetChanged: (name, value) {
                changedFields.add('$name:${value ?? "null"}');
              },
            ),
          ),
        ),
      );

      // Find and tap the clear button (second field's clear button)
      expect(find.byIcon(Icons.clear), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Should call onTargetChanged with null
      expect(changedFields, contains('Heart Rate:null'));
    });

    testWidgets('clear button is hidden when field is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTargetFieldsWidget(
              machineType: DeviceType.rower,
              userSettings: userSettings,
              config: config,
              targets: {},
              onTargetChanged: (name, value) {
                changedFields.add('$name:${value ?? "null"}');
              },
            ),
          ),
        ),
      );

      // No clear buttons should be visible initially
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('clear button appears when field gets a value', (WidgetTester tester) async {
      Map<String, dynamic> testTargets = {};

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return EditTargetFieldsWidget(
                  machineType: DeviceType.rower,
                  userSettings: userSettings,
                  config: config,
                  targets: testTargets,
                  onTargetChanged: (name, value) {
                    setState(() {
                      if (value == null) {
                        testTargets.remove(name);
                      } else {
                        testTargets[name] = value;
                      }
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // No clear buttons initially
      expect(find.byIcon(Icons.clear), findsNothing);

      // Enter a value
      await tester.enterText(find.byType(TextFormField).first, '75');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });
}