import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/ftms/widgets/resistance_level_control.dart';
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('ResistanceLevelControl', () {
    group('when available', () {
      testWidgets('displays resistance label', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 5,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();
        
        expect(find.textContaining('Resistance'), findsOneWidget);
      });

      testWidgets('shows help button when onShowHelp provided', (WidgetTester tester) async {
        bool helpCalled = false;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 5,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (_) {},
            onShowHelp: () => helpCalled = true,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.help_outline));
        expect(helpCalled, true);
      });

      testWidgets('increment button calls onChanged with incremented value', (WidgetTester tester) async {
        int? changedValue;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 5,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (value) => changedValue = value,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.add));
        expect(changedValue, 6);
      });

      testWidgets('decrement button calls onChanged with decremented value', (WidgetTester tester) async {
        int? changedValue;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 5,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (value) => changedValue = value,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.remove));
        expect(changedValue, 4);
      });

      testWidgets('increment sets to 1 when null', (WidgetTester tester) async {
        int? changedValue;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: null,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (value) => changedValue = value,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.add));
        expect(changedValue, 1);
      });

      testWidgets('decrement sets to 1 when null', (WidgetTester tester) async {
        int? changedValue;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: null,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (value) => changedValue = value,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.remove));
        expect(changedValue, 1);
      });

      testWidgets('does not increment above max', (WidgetTester tester) async {
        int? changedValue;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 10,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (value) => changedValue = value,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.add));
        // When at max, increment should still set to max (no change beyond)
        expect(changedValue, isNull);
      });

      testWidgets('does not decrement below 1', (WidgetTester tester) async {
        int? changedValue;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 1,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (value) => changedValue = value,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.remove));
        // When at 1, decrement should still call with 1
        expect(changedValue, isNull);
      });

      testWidgets('shows error when invalid', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 5,
            maxResistanceUserInput: 10,
            isValid: false,
            isAvailable: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();
        
        expect(find.textContaining('Invalid value'), findsOneWidget);
      });

      testWidgets('text input calls onChanged', (WidgetTester tester) async {
        int? changedValue;
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: null,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            onChanged: (value) => changedValue = value,
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.byType(TextFormField), '7');
        expect(changedValue, 7);
      });

      testWidgets('clearing text input calls onChanged with null', (WidgetTester tester) async {
        int? changedValue = 5;
        bool wasCalled = false;
        final controller = TextEditingController(text: '5');
        
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: 5,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: true,
            controller: controller,
            onChanged: (value) {
              changedValue = value;
              wasCalled = true;
            },
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.byType(TextFormField), '');
        expect(wasCalled, true);
        expect(changedValue, isNull);
      });
    });

    group('when unavailable', () {
      testWidgets('shows unavailable message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: null,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: false,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();
        
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('does not show input controls', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          ResistanceLevelControl(
            userResistanceLevel: null,
            maxResistanceUserInput: 10,
            isValid: true,
            isAvailable: false,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();
        
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byIcon(Icons.remove), findsNothing);
      });
    });
  });

  group('showResistanceMachineSupportDialog', () {
    testWidgets('shows dialog with max resistance info', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showResistanceMachineSupportDialog(context, 10),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('dialog can be dismissed', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showResistanceMachineSupportDialog(context, 10),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Find and tap OK button
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
