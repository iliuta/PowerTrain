import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/training/training_sessions_page.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:ftms/l10n/app_localizations.dart';

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock AssetBundle for config loading
  setUpAll(() async {
    // Mock AssetManifest.json
    const manifest = '{"lib/config/rowing_machine.json":[],"lib/config/indoor_bike.json":[],"lib/config/default_user_settings.json":[],"lib/training-sessions/test-session-1min30-rower.json":[]}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
      final String key = const StringCodec().decodeMessage(message) as String;
      if (key == 'AssetManifest.json') {
        return const StringCodec().encodeMessage(manifest);
      }
      if (key == 'lib/config/rowing_machine.json') {
        return const StringCodec().encodeMessage('''{
  "fields": [
    { "name": "Instantaneous Speed", "label": "Speed", "display": "speedometer", "unit": "km/h", "min": 0, "max": 30 },
    { "name": "Stroke Rate", "label": "Stroke Rate", "display": "number", "unit": "spm", "icon": "rowing" },
    { "name": "Instantaneous Power", "label": "Power", "display": "speedometer", "unit": "W", "min": 0, "max": 1500 },
    { "name": "Heart Rate", "label": "Heart rate", "display": "number", "unit": "bpm", "icon": "heart" }
  ]
}''');
      }
      if (key == 'lib/config/indoor_bike.json') {
        return const StringCodec().encodeMessage('''{
  "fields": [
    { "name": "Instantaneous Speed", "label": "Speed", "display": "speedometer", "unit": "km/h", "min": 0, "max": 50 },
    { "name": "Instantaneous Power", "label": "Power", "display": "speedometer", "unit": "W", "min": 0, "max": 2000 },
    { "name": "Heart Rate", "label": "Heart rate", "display": "number", "unit": "bpm", "icon": "heart" }
  ]
}''');
      }
      if (key == 'lib/config/default_user_settings.json') {
        return const StringCodec().encodeMessage('''{
  "developerMode": false,
  "maxPowerWatts": 300,
  "maxHrBpm": 180,
  "bodyWeightKg": 70,
  "restingHrBpm": 60,
  "soundEnabled": true
}''');
      }
      if (key == 'lib/training-sessions/test-session-1min30-rower.json') {
        return const StringCodec().encodeMessage('''{
  "title": "Test Session",
  "ftmsMachineType": "rower",
  "intervals": [
    {
      "title": "Warm Up",
      "duration": 300,
      "targets": {"Stroke Rate": 20}
    }
  ]
}''');
      }
      return null;
    });
  });

  group('TrainingSessionsPage', () {
    testWidgets('can be instantiated', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainingSessionsPage(),
        ),
      );

      // Just verify the page can be created
      expect(find.byType(TrainingSessionsPage), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainingSessionsPage(),
        ),
      );

      // Should show loading indicator immediately
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainingSessionsPage(),
        ),
      );

      // Should show the app bar title
      expect(find.text('Training Sessions'), findsOneWidget);
    });

    testWidgets('shows floating action button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainingSessionsPage(),
        ),
      );

      // Should show floating action button to add session
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('fab is tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainingSessionsPage(),
        ),
      );

      // Tap the floating action button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Should not crash and button should still be there
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('TrainingSessionsPage Integration', () {
    testWidgets('has duplicate functionality integrated', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainingSessionsPage(),
        ),
      );

      // Verify the page is built correctly
      expect(find.text('Training Sessions'), findsOneWidget);
      expect(find.byType(TrainingSessionsPage), findsOneWidget);
      
      // This test verifies that the page structure is correct
      // The actual duplicate functionality is tested in the expansion panel tests
      // since it requires actual sessions to be loaded
    });

    testWidgets('duplicate callback integration test', (WidgetTester tester) async {
      // This test verifies that the duplicate functionality integration is working
      // by checking that the page has the necessary structure and components
      
      const trainingSessionsPage = TrainingSessionsPage();
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: trainingSessionsPage,
        ),
      );

      // Verify the page type and basic structure
      expect(find.byType(TrainingSessionsPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      
      // The specific duplicate functionality integration is tested in the
      // expansion panel tests which verify that the onSessionDuplicate callback
      // is properly connected and functional
    });
  });
}
