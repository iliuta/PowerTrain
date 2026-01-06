import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/fit_files/fit_file_detail_page.dart';
import 'package:ftms/core/services/fit/fit_file_manager.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fit_tool/fit_tool.dart';
import 'package:fl_chart/fl_chart.dart';

// Generate mocks
@GenerateMocks([FitFileManager])
import 'fit_file_detail_page_test.mocks.dart';

void main() {
  late MockFitFileManager mockFitFileManager;

  setUp(() {
    mockFitFileManager = MockFitFileManager();
  });

  group('FitFileDetailPage Widget Tests', () {
    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      final fitFileInfo = FitFileInfo(
        fileName: 'Test_Workout_20241116_1209.fit',
        filePath: '/test/path/Test_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Test Workout',
      );

      // Mock the getFitFileDetail to never complete (simulating loading)
      final completer = Completer<FitFileDetail?>();
      when(mockFitFileManager.getFitFileDetail(fitFileInfo.filePath))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileDetailPage(
            fitFileInfo: fitFileInfo,
            fitFileManager: mockFitFileManager,
          ),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test Workout'), findsOneWidget); // AppBar title
    });

    testWidgets('should display no data available when detail is null', (WidgetTester tester) async {
      final fitFileInfo = FitFileInfo(
        fileName: 'Test_Workout_20241116_1209.fit',
        filePath: '/test/path/Test_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Test Workout',
      );

      when(mockFitFileManager.getFitFileDetail(fitFileInfo.filePath))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileDetailPage(
            fitFileInfo: fitFileInfo,
            fitFileManager: mockFitFileManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show no data available message
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
      expect(find.text('No data available'), findsOneWidget);
    });

    testWidgets('should display no data available when dataPoints is empty', (WidgetTester tester) async {
      final fitFileInfo = FitFileInfo(
        fileName: 'Test_Workout_20241116_1209.fit',
        filePath: '/test/path/Test_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Test Workout',
      );

      final fitFileDetail = FitFileDetail(
        fileName: 'Test_Workout_20241116_1209.fit',
        filePath: '/test/path/Test_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Test Workout',
        sport: Sport.cycling,
        totalDistance: 10000,
        totalTime: const Duration(minutes: 30),
        dataPoints: [], // Empty data points
      );

      when(mockFitFileManager.getFitFileDetail(fitFileInfo.filePath))
          .thenAnswer((_) async => fitFileDetail);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileDetailPage(
            fitFileInfo: fitFileInfo,
            fitFileManager: mockFitFileManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show no data available message
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
      expect(find.text('No data available'), findsOneWidget);
    });

    testWidgets('should display cycling workout data with graphs', (WidgetTester tester) async {
      final fitFileInfo = FitFileInfo(
        fileName: 'Cycling_Workout_20241116_1209.fit',
        filePath: '/test/path/Cycling_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Cycling Workout',
      );

      final dataPoints = [
        FitDataPoint(
          timestamp: DateTime(2024, 11, 16, 12, 9),
          speed: 8.33, // 30 km/h
          cadence: 90,
          heartRate: 150,
          power: 250,
          altitude: 100.0,
        ),
        FitDataPoint(
          timestamp: DateTime(2024, 11, 16, 12, 10),
          speed: 9.44, // 34 km/h
          cadence: 95,
          heartRate: 155,
          power: 280,
          altitude: 105.0,
        ),
      ];

      final fitFileDetail = FitFileDetail(
        fileName: 'Cycling_Workout_20241116_1209.fit',
        filePath: '/test/path/Cycling_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Cycling Workout',
        sport: Sport.cycling,
        totalDistance: 10000,
        totalTime: const Duration(minutes: 30),
        dataPoints: dataPoints,
      );

      when(mockFitFileManager.getFitFileDetail(fitFileInfo.filePath))
          .thenAnswer((_) async => fitFileDetail);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileDetailPage(
            fitFileInfo: fitFileInfo,
            fitFileManager: mockFitFileManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display summary information
      expect(find.text('Cycling Workout'), findsOneWidget);
      expect(find.textContaining('10.0 km'), findsOneWidget);
      expect(find.textContaining('30m'), findsOneWidget);

      // Should display graphs for all data types
      expect(find.byType(LineChart), findsWidgets); // Should have multiple charts
    });

    testWidgets('should display rowing workout data with pace graphs', (WidgetTester tester) async {
      final fitFileInfo = FitFileInfo(
        fileName: 'Rowing_Workout_20241116_1209.fit',
        filePath: '/test/path/Rowing_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Rowing Workout',
      );

      final dataPoints = [
        FitDataPoint(
          timestamp: DateTime(2024, 11, 16, 12, 9),
          speed: 4.0, // 4 m/s = 2:05/500m pace
          cadence: 25,
          heartRate: 140,
          power: 200,
        ),
        FitDataPoint(
          timestamp: DateTime(2024, 11, 16, 12, 10),
          speed: 4.5, // 4.5 m/s = 1:51/500m pace
          cadence: 28,
          heartRate: 145,
          power: 220,
        ),
      ];

      final fitFileDetail = FitFileDetail(
        fileName: 'Rowing_Workout_20241116_1209.fit',
        filePath: '/test/path/Rowing_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Rowing Workout',
        sport: Sport.rowing,
        totalDistance: 5000,
        totalTime: const Duration(minutes: 20),
        dataPoints: dataPoints,
      );

      when(mockFitFileManager.getFitFileDetail(fitFileInfo.filePath))
          .thenAnswer((_) async => fitFileDetail);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileDetailPage(
            fitFileInfo: fitFileInfo,
            fitFileManager: mockFitFileManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display summary information
      expect(find.text('Rowing Workout'), findsOneWidget);
      expect(find.textContaining('5.0 km'), findsOneWidget);
      expect(find.textContaining('20m'), findsOneWidget);

      // Should display graphs (pace for rowing)
      expect(find.byType(LineChart), findsWidgets);
    });

    testWidgets('should not display graphs when data is zero or invalid', (WidgetTester tester) async {
      final fitFileInfo = FitFileInfo(
        fileName: 'Invalid_Workout_20241116_1209.fit',
        filePath: '/test/path/Invalid_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Invalid Workout',
      );

      final dataPoints = [
        FitDataPoint(
          timestamp: DateTime(2024, 11, 16, 12, 9),
          speed: 0.0, // Invalid speed
          cadence: 0, // Invalid cadence
          heartRate: 0, // Invalid heart rate
          power: 0, // Invalid power
        ),
      ];

      final fitFileDetail = FitFileDetail(
        fileName: 'Invalid_Workout_20241116_1209.fit',
        filePath: '/test/path/Invalid_Workout_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Invalid Workout',
        sport: Sport.cycling,
        totalDistance: 1000,
        totalTime: const Duration(minutes: 5),
        dataPoints: dataPoints,
      );

      when(mockFitFileManager.getFitFileDetail(fitFileInfo.filePath))
          .thenAnswer((_) async => fitFileDetail);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileDetailPage(
            fitFileInfo: fitFileInfo,
            fitFileManager: mockFitFileManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display summary but no graphs (since all data is invalid/zero)
      expect(find.text('Invalid Workout'), findsOneWidget);
      expect(find.textContaining('1.0 km'), findsOneWidget);

      // Should not display any graphs
      expect(find.text('Speed'), findsNothing);
      expect(find.text('Cadence'), findsNothing);
      expect(find.text('Heart Rate'), findsNothing);
      expect(find.text('Power'), findsNothing);
    });

    testWidgets('should detect rowing activity from activity name when sport is null', (WidgetTester tester) async {
      final fitFileInfo = FitFileInfo(
        fileName: 'Rowing_Session_20241116_1209.fit',
        filePath: '/test/path/Rowing_Session_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Rowing Session',
      );

      final dataPoints = [
        FitDataPoint(
          timestamp: DateTime(2024, 11, 16, 12, 9),
          speed: 4.0,
        ),
      ];

      final fitFileDetail = FitFileDetail(
        fileName: 'Rowing_Session_20241116_1209.fit',
        filePath: '/test/path/Rowing_Session_20241116_1209.fit',
        creationDate: DateTime(2024, 11, 16, 12, 9),
        fileSizeBytes: 1024,
        activityName: 'Rowing Session',
        sport: null, // No sport field
        totalDistance: 2000,
        totalTime: const Duration(minutes: 10),
        dataPoints: dataPoints,
      );

      when(mockFitFileManager.getFitFileDetail(fitFileInfo.filePath))
          .thenAnswer((_) async => fitFileDetail);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitFileDetailPage(
            fitFileInfo: fitFileInfo,
            fitFileManager: mockFitFileManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display graphs (indicating rowing detection worked)
      expect(find.byType(LineChart), findsWidgets);
    });
  });
}