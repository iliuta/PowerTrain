import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/settings/widgets/user_preferences_section.dart';
import 'package:ftms/l10n/app_localizations.dart';

void main() {
  late UserSettings testSettings;
  late ValueChanged<UserSettings> onChangedCallback;
  late UserSettings capturedSettings;

  setUp(() {
    testSettings = const UserSettings(
      cyclingFtp: 250,
      rowingFtp: '1:45',
      developerMode: false,
      soundEnabled: true,
    );

    capturedSettings = testSettings;
    onChangedCallback = (UserSettings settings) {
      capturedSettings = settings;
    };
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: UserPreferencesSection(
          userSettings: testSettings,
          onChanged: onChangedCallback,
        ),
      ),
    );
  }

  group('UserPreferencesSection Widget Tests', () {
    testWidgets('should display initial values correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Check section title and subtitle
      expect(find.text('Fitness Profile'), findsOneWidget);
      expect(find.text('Your personal fitness metrics for accurate training targets'), findsOneWidget);

      // Check cycling FTP display
      expect(find.text('Cycling FTP'), findsOneWidget);
      expect(find.text('250 watts'), findsOneWidget);

      // Check rowing FTP display
      expect(find.text('Rowing FTP'), findsOneWidget);
      expect(find.text('1:45 per 500m'), findsOneWidget);

      // Check developer mode
      expect(find.text('Developer Mode'), findsOneWidget);
      expect(find.text('Enable debugging options and beta features'), findsOneWidget);

      // Check switches - there should be 2 now (developer mode and sound alerts)
      expect(find.byType(Switch), findsNWidgets(1));

      // Check developer mode switch is off (second switch)
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, false); // developer mode switch

    });

    testWidgets('should enter cycling FTP edit mode when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap on cycling FTP field
      await tester.tap(find.text('250 watts'));
      await tester.pump();

      // Should show text field
      expect(find.byType(TextField), findsOneWidget);

      // Should show check and close buttons
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should save valid cycling FTP', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('250 watts'));
      await tester.pump();

      // Enter new value
      final textField = find.byType(TextField);
      await tester.enterText(textField, '300');
      await tester.pump();

      // Tap check button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // Should call onChanged with new value
      expect(capturedSettings.cyclingFtp, 300);
      expect(capturedSettings.rowingFtp, '1:45');
      expect(capturedSettings.developerMode, false);
    });

    testWidgets('should show error for invalid cycling FTP (too low)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('250 watts'));
      await tester.pump();

      // Enter invalid value (too low)
      final textField = find.byType(TextField);
      await tester.enterText(textField, '30');
      await tester.pump();

      // Tap check button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // Should show error snackbar
      expect(find.text('Please enter a valid FTP (50-1000 watts)'), findsOneWidget);

      // Should not call onChanged
      expect(capturedSettings.cyclingFtp, 250);
    });

    testWidgets('should show error for invalid cycling FTP (too high)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('250 watts'));
      await tester.pump();

      // Enter invalid value (too high)
      final textField = find.byType(TextField);
      await tester.enterText(textField, '1500');
      await tester.pump();

      // Tap check button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // Should show error snackbar
      expect(find.text('Please enter a valid FTP (50-1000 watts)'), findsOneWidget);

      // Should not call onChanged
      expect(capturedSettings.cyclingFtp, 250);
    });

    testWidgets('should cancel cycling FTP editing', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('250 watts'));
      await tester.pump();

      // Enter new value
      final textField = find.byType(TextField);
      await tester.enterText(textField, '300');
      await tester.pump();

      // Tap cancel button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Should revert to original value and exit edit mode
      expect(find.text('250 watts'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Should not call onChanged
      expect(capturedSettings.cyclingFtp, 250);
    });

    testWidgets('should enter rowing FTP edit mode when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap on rowing FTP field
      await tester.tap(find.text('1:45 per 500m'));
      await tester.pump();

      // Should show text field
      expect(find.byType(TextField), findsOneWidget);

      // Should show check and close buttons
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should save valid rowing FTP', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('1:45 per 500m'));
      await tester.pump();

      // Enter new value
      final textField = find.byType(TextField);
      await tester.enterText(textField, '2:15');
      await tester.pump();

      // Tap check button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // Should call onChanged with new value
      expect(capturedSettings.cyclingFtp, 250);
      expect(capturedSettings.rowingFtp, '2:15');
      expect(capturedSettings.developerMode, false);
    });

    testWidgets('should show error for invalid rowing FTP format', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('1:45 per 500m'));
      await tester.pump();

      // Enter invalid format
      final textField = find.byType(TextField);
      await tester.enterText(textField, '1:60');
      await tester.pump();

      // Tap check button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // Should show error snackbar
      expect(find.text('Please enter a valid time format (M:SS)'), findsOneWidget);

      // Should not call onChanged
      expect(capturedSettings.rowingFtp, '1:45');
    });

    testWidgets('should show error for invalid rowing FTP (too many minutes)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('1:45 per 500m'));
      await tester.pump();

      // Enter invalid value (too many minutes)
      final textField = find.byType(TextField);
      await tester.enterText(textField, '15:30');
      await tester.pump();

      // Tap check button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // Should show error snackbar
      expect(find.text('Please enter a valid time format (M:SS)'), findsOneWidget);

      // Should not call onChanged
      expect(capturedSettings.rowingFtp, '1:45');
    });

    testWidgets('should cancel rowing FTP editing', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('1:45 per 500m'));
      await tester.pump();

      // Enter new value
      final textField = find.byType(TextField);
      await tester.enterText(textField, '2:15');
      await tester.pump();

      // Tap cancel button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Should revert to original value and exit edit mode
      expect(find.text('1:45 per 500m'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Should not call onChanged
      expect(capturedSettings.rowingFtp, '1:45');
    });

    testWidgets('should toggle developer mode via switch', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Find the developer mode switch specifically (it's the second switch)
      final switches = find.byType(Switch);
      await tester.tap(switches.at(0)); // developer mode switch
      await tester.pump();

      // Should call onChanged with developer mode enabled
      expect(capturedSettings.cyclingFtp, 250);
      expect(capturedSettings.rowingFtp, '1:45');
      expect(capturedSettings.developerMode, true);
    });

    testWidgets('should toggle developer mode via list tile tap', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap the list tile (not the switch)
      await tester.tap(find.text('Developer Mode'));
      await tester.pump();

      // Should call onChanged with developer mode enabled
      expect(capturedSettings.developerMode, true);
    });

    testWidgets('should update controllers when userSettings changes', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Update settings externally
      testSettings = const UserSettings(
        cyclingFtp: 300,
        rowingFtp: '2:00',
        developerMode: true,
        soundEnabled: false,
      );

      // Rebuild widget
      await tester.pumpWidget(createWidgetUnderTest());

      // Should display updated values
      expect(find.text('300 watts'), findsOneWidget);
      expect(find.text('2:00 per 500m'), findsOneWidget);

      // Developer mode switch should be on (second switch)
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, true); // developer mode switch

    });

    testWidgets('should handle keyboard submission for cycling FTP', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('250 watts'));
      await tester.pump();

      // Enter new value and submit via keyboard
      final textField = find.byType(TextField);
      await tester.enterText(textField, '275');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Should call onChanged with new value
      expect(capturedSettings.cyclingFtp, 275);
    });

    testWidgets('should handle keyboard submission for rowing FTP', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('1:45 per 500m'));
      await tester.pump();

      // Enter new value and submit via keyboard
      final textField = find.byType(TextField);
      await tester.enterText(textField, '1:50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Should call onChanged with new value
      expect(capturedSettings.rowingFtp, '1:50');
    });

    testWidgets('should restrict cycling FTP input to digits only', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter edit mode
      await tester.tap(find.text('250 watts'));
      await tester.pump();

      // Try to enter non-numeric characters
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'abc250def');
      await tester.pump();

      // Should only contain digits
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, '250');
    });
  });

  group('UserPreferencesSection Developer Mode Visibility Tests', () {
    // Test configs for developer mode visibility tests
    final indoorBikeConfig = LiveDataDisplayConfig(
      deviceType: DeviceType.indoorBike,
      availableInDeveloperModeOnly: true,
      fields: [
        LiveDataFieldConfig(name: 'Power', label: 'Power', display: 'number', unit: 'W'),
      ],
    );
    
    final rowerConfig = LiveDataDisplayConfig(
      deviceType: DeviceType.rower,
      availableInDeveloperModeOnly: false,
      fields: [
        LiveDataFieldConfig(name: 'Pace', label: 'Pace', display: 'speedometer', unit: 's/500m'),
      ],
    );

    testWidgets('should hide cycling FTP when developerMode is off and config is developer-only',
        (WidgetTester tester) async {
      // Inject test configs directly
      LiveDataDisplayConfig.clearCache();
      LiveDataDisplayConfig.setTestConfig(DeviceType.indoorBike, indoorBikeConfig);
      LiveDataDisplayConfig.setTestConfig(DeviceType.rower, rowerConfig);
      
      // developerMode is OFF by default in testSettings
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Cycling FTP should NOT be visible (indoor_bike config has availableInDeveloperModeOnly: true)
      expect(find.text('Cycling FTP'), findsNothing);
      
      // Rowing FTP should still be visible (rower config has availableInDeveloperModeOnly: false)
      expect(find.text('Rowing FTP'), findsOneWidget);
    });

    testWidgets('should show cycling FTP when developerMode is on',
        (WidgetTester tester) async {
      // Inject test configs directly
      LiveDataDisplayConfig.clearCache();
      LiveDataDisplayConfig.setTestConfig(DeviceType.indoorBike, indoorBikeConfig);
      LiveDataDisplayConfig.setTestConfig(DeviceType.rower, rowerConfig);
      
      testSettings = const UserSettings(
        cyclingFtp: 250,
        rowingFtp: '1:45',
        developerMode: true,
        soundEnabled: true,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Cycling FTP should be visible when in developer mode
      expect(find.text('Cycling FTP'), findsOneWidget);
      expect(find.text('250 watts'), findsOneWidget);
    });

    testWidgets('should always show rowing FTP regardless of developerMode',
        (WidgetTester tester) async {
      // Inject test configs directly
      LiveDataDisplayConfig.clearCache();
      LiveDataDisplayConfig.setTestConfig(DeviceType.indoorBike, indoorBikeConfig);
      LiveDataDisplayConfig.setTestConfig(DeviceType.rower, rowerConfig);
      
      // developerMode is OFF
      testSettings = const UserSettings(
        cyclingFtp: 250,
        rowingFtp: '1:45',
        developerMode: false,
        soundEnabled: true,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Rowing FTP should always be visible (config has availableInDeveloperModeOnly: false)
      expect(find.text('Rowing FTP'), findsOneWidget);
      expect(find.text('1:45 per 500m'), findsOneWidget);
    });
  });
}