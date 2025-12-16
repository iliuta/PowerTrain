import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/features/common/burger_menu.dart';

// Mock BluetoothDevice for testing
@GenerateMocks([BluetoothDevice])
void main() {
  group('BurgerMenu', () {
    testWidgets('should show all menu items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [BurgerMenu()],
            ),
          ),
        ),
      );

      // Tap the menu button
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Should show all menu items
      expect(find.text('Training Sessions'), findsOneWidget);
      expect(find.text('Unsynchronized activities'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Should show appropriate icons
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should have FIT Files menu item that can be tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [BurgerMenu()],
            ),
          ),
        ),
      );

      // Tap the menu button
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();

      // Should show FIT Files menu item
      expect(find.text('Unsynchronized activities'), findsOneWidget);
      
      // Verify the menu item can be found and is tappable
      final fitFilesItem = find.text('Unsynchronized activities');
      expect(fitFilesItem, findsOneWidget);
      
      // Verify it's actually a menu item (inside PopupMenuItem)
      final popupMenuItem = find.ancestor(
        of: fitFilesItem,
        matching: find.byType(PopupMenuItem<String>),
      );
      expect(popupMenuItem, findsOneWidget);
    });

    testWidgets('should show menu tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [BurgerMenu()],
            ),
          ),
        ),
      );

      final menuButton = find.byType(PopupMenuButton<String>);
      expect(menuButton, findsOneWidget);

      // Get the PopupMenuButton widget and check its tooltip
      final popupMenuButton = tester.widget<PopupMenuButton<String>>(menuButton);
      expect(popupMenuButton.tooltip, 'Menu');
    });

    testWidgets('should show menu icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [BurgerMenu()],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('should handle menu selection properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [BurgerMenu()],
            ),
          ),
        ),
      );

      // Test that menu can be opened and closed
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Menu should be open
      expect(find.text('Training Sessions'), findsOneWidget);

      // Tap outside to close menu
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Menu should be closed
      expect(find.text('Training Sessions'), findsNothing);
    });
  });
}
