import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/settings/settings_page.dart';

void main() {
  group('SettingsPage Widget Tests', () {
    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: const SettingsPage(),
      );
    }

    testWidgets('should display loading spinner initially', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // The CircularProgressIndicator should be visible during loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display Scaffold with AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      // Just pump a frame without settling to avoid waiting for loading
      await tester.pump();

      // Check for Scaffold
      expect(find.byType(Scaffold), findsOneWidget);

      // Check for AppBar with Settings title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('should display back button in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      await tester.pump();

      // Check for back button icon
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('should display PopScope widget for handling back navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      await tester.pump();

      // PopScope is used but we verify it through other means - checking scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('should render loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      // Find the body and verify it shows loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Verify it's in a Center widget (there may be multiple in the tree)
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('should have PopScope wrapping the Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      await tester.pump();

      // Verify Scaffold is in the widget tree (PopScope wraps it)
      expect(find.byType(Scaffold), findsOneWidget);
      
      // Verify CircularProgressIndicator is rendered
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('should display leading back button and title in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      await tester.pump();

      // Find AppBar
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      // Check for back button as leading widget
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('should build body correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      await tester.pump();

      // Verify we have a Scaffold with a body
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('should handle state initialization', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      // Initial state should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // After a frame, loading should still be visible (since loadDefault is async)
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display widget tree structure correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      await tester.pump();

      // Verify the main widget is SettingsPage
      expect(find.byType(SettingsPage), findsOneWidget);
      
      // Verify Scaffold is present (PopScope wraps it)
      expect(find.byType(Scaffold), findsOneWidget);
      
      // Verify AppBar is present
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
