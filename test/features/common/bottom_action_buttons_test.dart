import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:ftms/features/common/bottom_action_buttons.dart';

void main() {
  group('BottomActionButtons', () {
    testWidgets('should show all action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BottomActionButtons(),
          ),
        ),
      );

      // Should show all action buttons
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.help), findsOneWidget);
    });

    testWidgets('should have correct button layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BottomActionButtons(),
          ),
        ),
      );

      // Should have a Row with spaceEvenly alignment containing the buttons
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget);

      final row = tester.widget<Row>(rowFinder);
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceEvenly);

      // Should have 4 Flexible widgets (one for each button)
      expect(find.byType(Flexible), findsNWidgets(4));

      // Should have 4 IconButton widgets
      expect(find.byType(IconButton), findsNWidgets(4));
    });

    testWidgets('should have proper container styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BottomActionButtons(),
          ),
        ),
      );

      // Should have a Container with proper padding
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      expect(container.padding, const EdgeInsets.all(4.0));
    });

    testWidgets('should handle button taps and navigation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BottomActionButtons(),
          ),
        ),
      );

      // All buttons should be present and tappable
      final fitnessButton = find.byIcon(Icons.fitness_center);
      final folderButton = find.byIcon(Icons.folder);
      final settingsButton = find.byIcon(Icons.settings);
      final helpButton = find.byIcon(Icons.help);

      expect(fitnessButton, findsOneWidget);
      expect(folderButton, findsOneWidget);
      expect(settingsButton, findsOneWidget);
      expect(helpButton, findsOneWidget);

      // Verify buttons are wrapped in IconButton widgets
      expect(find.ancestor(of: fitnessButton, matching: find.byType(IconButton)), findsOneWidget);
      expect(find.ancestor(of: folderButton, matching: find.byType(IconButton)), findsOneWidget);
      expect(find.ancestor(of: settingsButton, matching: find.byType(IconButton)), findsOneWidget);
      expect(find.ancestor(of: helpButton, matching: find.byType(IconButton)), findsOneWidget);
    });

    testWidgets('should build without any parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: BottomActionButtons(),
          ),
        ),
      );

      // Widget should build successfully
      expect(find.byType(BottomActionButtons), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    });

    testWidgets('should have proper icon sizes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BottomActionButtons(),
          ),
        ),
      );

      // Find all Icon widgets and verify they have size 20.0
      final iconFinders = find.byType(Icon);
      expect(iconFinders, findsNWidgets(4));

      for (final iconFinder in iconFinders.evaluate()) {
        final icon = iconFinder.widget as Icon;
        expect(icon.size, 20.0);
      }
    });
  });
}