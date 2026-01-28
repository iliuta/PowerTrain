import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/ftms/models/session_selector_state.dart';
import 'package:ftms/features/ftms/widgets/free_ride_config_panel.dart';
import 'package:ftms/features/ftms/widgets/duration_distance_picker.dart';
import 'package:ftms/features/ftms/widgets/resistance_level_control.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget createTestWidget({
  required Widget child,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  final defaultUserSettings = UserSettings(
    cyclingFtp: 200,
    rowingFtp: '2:00',
    developerMode: false,
    soundEnabled: true,
  );
  final defaultDisplayConfig = LiveDataDisplayConfig(
    fields: [],
    deviceType: DeviceType.rower,
  );

  group('FreeRideConfigPanel', () {
    testWidgets('renders with required components', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Should render duration/distance picker
      expect(find.byType(DurationDistancePicker), findsOneWidget);
      
      // Should render "Targets" label
      expect(find.text('Targets'), findsOneWidget);
      
      // Should render start button
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('renders warmup and cooldown switches for rower', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Should render warmup and cooldown switches for rower
      expect(find.text('Warm up'), findsOneWidget);
      expect(find.text('Cool down'), findsOneWidget);
      expect(find.byType(Switch), findsAtLeastNWidgets(2));
    });

    testWidgets('does not render warmup/cooldown for indoor bike', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(),
          deviceType: DeviceType.indoorBike,
          userSettings: defaultUserSettings,
          displayConfig: LiveDataDisplayConfig(fields: [], deviceType: DeviceType.indoorBike),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Should NOT render warmup and cooldown switches for indoor bike
      expect(find.text('Warm up'), findsNothing);
      expect(find.text('Cool down'), findsNothing);
    });

    testWidgets('renders resistance control for rower', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ResistanceLevelControl), findsOneWidget);
    });

    testWidgets('renders resistance control for indoor bike', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(),
          deviceType: DeviceType.indoorBike,
          userSettings: defaultUserSettings,
          displayConfig: LiveDataDisplayConfig(fields: [], deviceType: DeviceType.indoorBike),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ResistanceLevelControl), findsOneWidget);
    });

    testWidgets('calls onWarmupChanged when warmup switch toggled', (WidgetTester tester) async {
      bool? warmupValue;
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(hasWarmup: false),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (value) => warmupValue = value,
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Find warmup switch by finding the Row containing "Warm up" text
      final warmupText = find.text('Warm up');
      expect(warmupText, findsOneWidget);
      
      // Find the switch that is a sibling to the warmup text (in same Row)
      final warmupRow = find.ancestor(of: warmupText, matching: find.byType(Row)).first;
      final warmupSwitch = find.descendant(of: warmupRow, matching: find.byType(Switch));
      await tester.tap(warmupSwitch);
      await tester.pumpAndSettle();

      expect(warmupValue, true);
    });

    testWidgets('calls onCooldownChanged when cooldown switch toggled', (WidgetTester tester) async {
      bool? cooldownValue;
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(hasCooldown: false),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (value) => cooldownValue = value,
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Find cooldown switch by finding the Row containing "Cool down" text
      final cooldownText = find.text('Cool down');
      expect(cooldownText, findsOneWidget);
      
      final cooldownRow = find.ancestor(of: cooldownText, matching: find.byType(Row)).first;
      final cooldownSwitch = find.descendant(of: cooldownRow, matching: find.byType(Switch));
      await tester.tap(cooldownSwitch);
      await tester.pumpAndSettle();

      expect(cooldownValue, true);
    });

    testWidgets('calls onStart when start button pressed', (WidgetTester tester) async {
      bool startPressed = false;
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () => startPressed = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(startPressed, true);
    });

    testWidgets('start button disabled when resistance level is invalid', (WidgetTester tester) async {
      bool startPressed = false;
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(isResistanceLevelValid: false),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () => startPressed = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Start should not be called because button is disabled
      expect(startPressed, false);
    });

    testWidgets('displays current duration value', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(durationMinutes: 45),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('switch values reflect config state', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        child: FreeRideConfigPanel(
          config: const FreeRideConfig(hasWarmup: true, hasCooldown: false),
          deviceType: DeviceType.rower,
          userSettings: defaultUserSettings,
          displayConfig: defaultDisplayConfig,
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onTargetChanged: (_, _) {},
          onResistanceChanged: (_) {},
          onWarmupChanged: (_) {},
          onCooldownChanged: (_) {},
          onStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Find warmup switch by its row
      final warmupText = find.text('Warm up');
      final warmupRow = find.ancestor(of: warmupText, matching: find.byType(Row)).first;
      final warmupSwitch = tester.widget<Switch>(
        find.descendant(of: warmupRow, matching: find.byType(Switch)),
      );
      expect(warmupSwitch.value, true);
      
      // Find cooldown switch by its row
      final cooldownText = find.text('Cool down');
      final cooldownRow = find.ancestor(of: cooldownText, matching: find.byType(Row)).first;
      final cooldownSwitch = tester.widget<Switch>(
        find.descendant(of: cooldownRow, matching: find.byType(Switch)),
      );
      expect(cooldownSwitch.value, false);
    });
  });
}
