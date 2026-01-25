import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/utils/responsive_utils.dart';

void main() {
  group('ResponsiveUtils', () {
    testWidgets('scaleFactor returns a value between 1.0 and 3.0', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final scale = ResponsiveUtils.scaleFactor(context);
              // Scale factor should always be in valid range
              expect(scale, greaterThanOrEqualTo(1.0));
              expect(scale, lessThanOrEqualTo(3.0));
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('getOptimalColumnCount returns 3 or 4', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final columnCount = ResponsiveUtils.getOptimalColumnCount(context);
              // Should return either 3 or 4 depending on orientation
              expect(columnCount, isIn([3, 4]));
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('isBigScreen returns a boolean', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final isBig = ResponsiveUtils.isBigScreen(context);
              // Should return a boolean value
              expect(isBig, isA<bool>());
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('getOptimalColumnCount returns 3 in portrait', (WidgetTester tester) async {
      // Force portrait orientation
      tester.binding.platformDispatcher.views.first.physicalSize = const Size(400, 800);
      addTearDown(tester.binding.platformDispatcher.views.first.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final orientation = MediaQuery.of(context).orientation;
              // In portrait, should return 3
              if (orientation == Orientation.portrait) {
                expect(ResponsiveUtils.getOptimalColumnCount(context), 3);
              }
              return const Scaffold();
            },
          ),
        ),
      );
    });
  });
}
