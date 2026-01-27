import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/fit_files/fit_file_manager_page.dart';
import 'package:ftms/core/services/fit/fit_file_manager.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ftms/core/services/strava/strava_service.dart';

// Generate mocks
@GenerateMocks([FitFileManager, StravaService])
import 'fit_file_manager_page_test.mocks.dart';

void main() {
  late MockFitFileManager mockFitFileManager;
  late MockStravaService mockStravaService;

  setUp(() {
    mockFitFileManager = MockFitFileManager();
    mockStravaService = MockStravaService();
  });

  group('FitFileManagerPage Widget Tests', () {
    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should load and display FIT files', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
        FitFileInfo(
          fileName: 'Another_Workout_20241116_1210.fit',
          filePath: '/test/path/Another_Workout_20241116_1210.fit',
          creationDate: DateTime(2024, 11, 16, 12, 10),
          fileSizeBytes: 2048,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      // Wait for files to load
      await tester.pumpAndSettle();

      // Should display the files with extracted activity names
      expect(find.text('Test Workout - PowerTrain'), findsOneWidget);
      expect(find.text('Another Workout - PowerTrain'), findsOneWidget);
      expect(find.text('1.0KB'), findsOneWidget);
      expect(find.text('2.0KB'), findsOneWidget);
    });

    testWidgets('should toggle file selection when tapping checkbox', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially no files selected, no FAB
      expect(find.byType(FloatingActionButton), findsNothing);

      // Tap the checkbox to select the file
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Now FAB should appear
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Delete Selected'), findsOneWidget);

      // Tap again to deselect
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // FAB should disappear
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('should show delete confirmation dialog and delete files', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);
      when(mockFitFileManager.deleteFitFiles(any)).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 2000)),
            child: Scaffold(
              body: FitFileManagerPage(
                fitFileManager: mockFitFileManager,
                stravaService: mockStravaService,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select the file
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Verify FAB is shown
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Instead of direct method call, use the popup menu to trigger delete
      // Find the popup menu button for the file
      final popupMenuFinder = find.byType(PopupMenuButton<String>).first;
      await tester.tap(popupMenuFinder);
      await tester.pumpAndSettle();

      // Select the delete option
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Delete FIT Files'), findsOneWidget);
      expect(find.text('Are you sure you want to delete 1 selected file(s)? This action cannot be undone.'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Should show success message
      expect(find.text('Successfully deleted 1 file(s)'), findsOneWidget);
    });

    testWidgets('should cancel delete when user taps cancel', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 2000)),
            child: Scaffold(
              body: FitFileManagerPage(
                fitFileManager: mockFitFileManager,
                stravaService: mockStravaService,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select the file
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Verify FAB is shown
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Use the popup menu to trigger delete confirmation dialog
      final popupMenuFinder = find.byType(PopupMenuButton<String>).first;
      await tester.tap(popupMenuFinder);
      await tester.pumpAndSettle();

      // Select the delete option
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Delete FIT Files'), findsOneWidget);
      expect(find.text('Are you sure you want to delete 1 selected file(s)? This action cannot be undone.'), findsOneWidget);

      // Cancel deletion
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // File should still be there
      expect(find.text('Test Workout - PowerTrain'), findsOneWidget);
      // Should not show success message
      expect(find.text('Successfully deleted 1 file(s)'), findsNothing);
    });

    testWidgets('should upload to Strava when popup menu upload is selected', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);
      when(mockStravaService.isAuthenticated()).thenAnswer((_) async => true);
      when(mockStravaService.uploadActivity(any, any, activityType: anyNamed('activityType'), context: anyNamed('context')))
          .thenAnswer((_) async => {'id': '12345', 'name': 'Test Activity'});
      when(mockFitFileManager.deleteFitFile(any)).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Select upload option
      await tester.tap(find.text('Upload to Strava'));
      await tester.pumpAndSettle();

      // Should show success message
      expect(find.text('Successfully uploaded to Strava and deleted local file'), findsOneWidget);
    });

    testWidgets('should show authentication error when uploading without auth', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);
      when(mockStravaService.isAuthenticated()).thenAnswer((_) async => false);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Select upload option
      await tester.tap(find.text('Upload to Strava'));
      await tester.pumpAndSettle();

      // Should show auth error
      expect(find.text('Please authenticate with Strava first in Settings'), findsOneWidget);
    });

    testWidgets('should share file when popup menu share is selected', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);

      await tester.pumpWidget(
        MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Select share option
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // Since SharePlus.share() is called, we can't easily verify the share dialog
      // but we can verify no error occurred (no error snackbar)
      expect(find.textContaining('Error sharing file'), findsNothing);
    });

    testWidgets('should delete single file from popup menu', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);
      when(mockFitFileManager.deleteFitFiles(any)).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Select delete option
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Delete FIT Files'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Should show success message
      expect(find.text('Successfully deleted 1 file(s)'), findsOneWidget);
    });

    testWidgets('should select all files when select all is tapped', (WidgetTester tester) async {
      final testFiles = [
        FitFileInfo(
          fileName: 'Test_Workout_20241116_1209.fit',
          filePath: '/test/path/Test_Workout_20241116_1209.fit',
          creationDate: DateTime(2024, 11, 16, 12, 9),
          fileSizeBytes: 1024,
        ),
        FitFileInfo(
          fileName: 'Another_Workout_20241116_1210.fit',
          filePath: '/test/path/Another_Workout_20241116_1210.fit',
          creationDate: DateTime(2024, 11, 16, 12, 10),
          fileSizeBytes: 2048,
        ),
      ];

      when(mockFitFileManager.getAllFitFiles()).thenAnswer((_) async => testFiles);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(
            fitFileManager: mockFitFileManager,
            stravaService: mockStravaService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pump();

      // Should show FAB for deleting all
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Delete Selected'), findsOneWidget);

      // Tap Deselect All
      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      // FAB should disappear
      expect(find.byType(FloatingActionButton), findsNothing);
    });
    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show loading state during initialization', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(),
        ),
      );

      expect(find.text('FIT Files'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should show refresh button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(),
        ),
      );

      // Verify the page builds successfully
      expect(find.byType(FitFileManagerPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('FitFileInfo Model Tests', () {
    testWidgets('page should build without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileManagerPage(),
        ),
      );

      // Verify the page builds successfully
      expect(find.byType(FitFileManagerPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
