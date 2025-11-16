import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/fit_files/fit_file_manager_page.dart';
import 'package:ftms/core/services/fit/fit_file_manager.dart';

void main() {
  group('FitFileManagerPage Widget Tests', () {
    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FitFileManagerPage(),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show loading state during initialization', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FitFileManagerPage(),
        ),
      );
      
      // Just test that the page loads without crashing
      // Wait a bit for initial load but don't wait for full settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show app bar with title and refresh button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FitFileManagerPage(),
        ),
      );

      expect(find.text('FIT Files'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should show refresh button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FitFileManagerPage(),
        ),
      );

      // Allow initial frame to render
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      
      // Test that refresh button can be tapped without waiting for async operations
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      
      // Should still show the refresh icon after tap
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should not show select all button when no files exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FitFileManagerPage(),
        ),
      );

      // Allow initial load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select All button only appears if files exist
      expect(find.text('Select All'), findsNothing);
      expect(find.text('Deselect All'), findsNothing);
    });

    testWidgets('should not show FAB when no files selected', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FitFileManagerPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No FAB should be shown initially
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('page should build without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FitFileManagerPage(),
        ),
      );

      // Verify the page builds successfully
      expect(find.byType(FitFileManagerPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('FitFileInfo Model Tests', () {
    test('should format file size correctly for bytes', () {
      final smallFile = FitFileInfo(
        fileName: 'small.fit',
        filePath: '/path/small.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 512,
      );
      expect(smallFile.formattedSize, '512B');
    });

    test('should format file size correctly for kilobytes', () {
      final mediumFile = FitFileInfo(
        fileName: 'medium.fit',
        filePath: '/path/medium.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 1536, // 1.5 KB
      );
      expect(mediumFile.formattedSize, '1.5KB');
    });

    test('should format file size correctly for megabytes', () {
      final largeFile = FitFileInfo(
        fileName: 'large.fit',
        filePath: '/path/large.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 2097152, // 2 MB
      );
      expect(largeFile.formattedSize, '2.0MB');
    });

    test('should format edge case: exactly 1KB', () {
      final file = FitFileInfo(
        fileName: 'test.fit',
        filePath: '/path/test.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 1024,
      );
      expect(file.formattedSize, '1.0KB');
    });

    test('should format edge case: exactly 1MB', () {
      final file = FitFileInfo(
        fileName: 'test.fit',
        filePath: '/path/test.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 1048576,
      );
      expect(file.formattedSize, '1.0MB');
    });

    test('should format 0 bytes', () {
      final file = FitFileInfo(
        fileName: 'empty.fit',
        filePath: '/path/empty.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 0,
      );
      expect(file.formattedSize, '0B');
    });

    test('should create FitFileInfo with all properties', () {
      final now = DateTime.now();
      final fitFile = FitFileInfo(
        fileName: 'test.fit',
        filePath: '/path/to/test.fit',
        creationDate: now,
        fileSizeBytes: 1024,
      );

      expect(fitFile.fileName, 'test.fit');
      expect(fitFile.filePath, '/path/to/test.fit');
      expect(fitFile.creationDate, now);
      expect(fitFile.fileSizeBytes, 1024);
      expect(fitFile.formattedSize, '1.0KB');
    });

    test('should handle large file sizes correctly', () {
      final largeFile = FitFileInfo(
        fileName: 'large.fit',
        filePath: '/path/large.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 10485760, // 10 MB
      );
      expect(largeFile.formattedSize, '10.0MB');
    });

    test('should handle decimal precision for KB', () {
      final file = FitFileInfo(
        fileName: 'test.fit',
        filePath: '/path/test.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 1587, // ~1.55 KB
      );
      expect(file.formattedSize, '1.5KB');
    });

    test('should handle decimal precision for MB', () {
      final file = FitFileInfo(
        fileName: 'test.fit',
        filePath: '/path/test.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 1625292, // ~1.55 MB
      );
      expect(file.formattedSize, '1.5MB');
    });
  });

  group('File Name Extraction Tests', () {
    test('should extract activity name from filename', () {
      // Test the pattern used in _uploadToStrava
      final testCases = [
        ('Cycling_Workout_20241116_1209.fit', 'Cycling Workout'),
        ('Rowing_Session_20241116_1209.fit', 'Rowing Session'),
        ('Test_Run_20241116_1209.fit', 'Test Run'),
        ('Morning_Ride_20241116_1209.fit', 'Morning Ride'),
      ];

      for (final testCase in testCases) {
        final fileName = testCase.$1;
        final expectedName = testCase.$2;
        
        final baseName = fileName
            .replaceAll(RegExp(r'_\d{8}_\d{4}\.fit$'), '')
            .replaceAll('_', ' ');
        
        expect(baseName, expectedName);
      }
    });

    test('should handle filenames without timestamps', () {
      final fileName = 'Simple_Workout.fit';
      final baseName = fileName
          .replaceAll(RegExp(r'_\d{8}_\d{4}\.fit$'), '')
          .replaceAll('_', ' ');
      
      // Should still replace underscores
      expect(baseName, 'Simple Workout.fit');
    });

    test('should handle filenames with multiple underscores', () {
      final fileName = 'Long_Test_Cycling_Workout_20241116_1209.fit';
      final baseName = fileName
          .replaceAll(RegExp(r'_\d{8}_\d{4}\.fit$'), '')
          .replaceAll('_', ' ');
      
      expect(baseName, 'Long Test Cycling Workout');
    });
  });
}
