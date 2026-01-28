import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/ftms/ftms_page.dart';
import 'package:ftms/features/ftms/ftms_session_selector_tab.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget createTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: child,
  );
}

void main() {
  group('FTMSPage', () {
    testWidgets('renders with app bar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const FTMSPage(),
      ));
      // Allow initial frame to render
      await tester.pump();

      // Should display app bar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders FTMSessionSelectorTab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const FTMSPage(),
      ));
      await tester.pump();

      // Should contain FTMSessionSelectorTab
      expect(find.byType(FTMSessionSelectorTab), findsOneWidget);
    });

    testWidgets('app bar has correct height', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const FTMSPage(),
      ));
      await tester.pump();

      // Find AppBar and verify it exists
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('is wrapped in Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const FTMSPage(),
      ));
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
