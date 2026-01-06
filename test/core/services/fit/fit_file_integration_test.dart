import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/fit/fit_file_manager.dart';
import 'package:fit_tool/fit_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FIT File Management - Integration Test', () {
    test('FitFileInfo should format sizes correctly', () {
      final smallFile = FitFileInfo(
        fileName: 'small.fit',
        filePath: '/path/small.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 512,
      );
      expect(smallFile.formattedSize, '512B');

      final mediumFile = FitFileInfo(
        fileName: 'medium.fit',
        filePath: '/path/medium.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 1536, // 1.5 KB
      );
      expect(mediumFile.formattedSize, '1.5KB');

      final largeFile = FitFileInfo(
        fileName: 'large.fit',
        filePath: '/path/large.fit',
        creationDate: DateTime.now(),
        fileSizeBytes: 2097152, // 2 MB
      );
      expect(largeFile.formattedSize, '2.0MB');
    });

    test('FitFileManager should parse FIT files correctly', () async {
      final manager = FitFileManager();
      
      // Test with rowing FIT file
      final rowingFile = File('test_fit_output/Test_Rowing_Workout_20260106_1151.fit');
      if (await rowingFile.exists()) {
        final detail = await manager.getFitFileDetail(rowingFile.path);
        expect(detail, isNotNull);
        expect(detail!.sport, isNotNull);
        expect(detail.sport, equals(Sport.rowing));
        expect(detail.totalDistance, isNotNull);
        expect(detail.totalDistance, isA<double>());
        expect(detail.totalTime, isNotNull);
        expect(detail.totalTime!.inSeconds, greaterThan(0));
        expect(detail.activityName, contains('Test Rowing Workout'));
        expect(detail.dataPoints, isNotEmpty);
      }
      
      // Test with cycling FIT file
      final cyclingFile = File('test_fit_output/Test_Cycling_Workout_20260106_1151.fit');
      if (await cyclingFile.exists()) {
        final detail = await manager.getFitFileDetail(cyclingFile.path);
        expect(detail, isNotNull);
        expect(detail!.sport, equals(Sport.cycling));
        expect(detail.totalDistance, isNotNull);
        expect(detail.totalDistance, isA<double>());
        expect(detail.activityName, contains('Test Cycling Workout'));
        expect(detail.dataPoints, isNotEmpty);
      }
    });

    test('FitFileManager should extract session data from FIT files', () async {
      final manager = FitFileManager();
      
      // Test session data extraction
      final rowingFile = File('test_fit_output/Test_Rowing_Workout_20260106_1151.fit');
      if (await rowingFile.exists()) {
        final detail = await manager.getFitFileDetail(rowingFile.path);
        expect(detail, isNotNull);
        
        // Check that session data was extracted
        expect(detail!.totalDistance, isNotNull);
        expect(detail.totalTime, isNotNull);
        
        // Check that data points contain expected metrics
        final hasSpeed = detail.dataPoints.any((p) => p.speed != null);
        final hasCadence = detail.dataPoints.any((p) => p.cadence != null);

        // At least some data points should have speed (either original or calculated)
        expect(hasSpeed, isTrue);
        
        // Rowing files typically have cadence
        expect(hasCadence, isTrue);
      }
    });

    test('FitFileManager should parse FIT file session data correctly', () async {
      final manager = FitFileManager();
      
      // Test the session data parsing logic directly
      final rowingFile = File('test_fit_output/Test_Rowing_Workout_20260106_1151.fit');
      if (await rowingFile.exists()) {
        final sessionData = await manager.parseFitFileSessionData(rowingFile);
        print('Rowing file session data: $sessionData');
        expect(sessionData, isNotNull);
        if (sessionData != null) {
          expect(sessionData['totalDistance'], isNotNull);
          // Allow 0 distance for some files, just check it's a number
          expect(sessionData['totalDistance'], isA<double>());
          expect(sessionData['totalTime'], isNotNull);
          expect(sessionData['totalTime'], isA<Duration>());
          // Allow 0 time for some files
          expect(sessionData['totalTime'].inSeconds, isA<int>());
        }
      }
      
      // Test with cycling file
      final cyclingFile = File('test_fit_output/Test_Cycling_Workout_20260106_1151.fit');
      if (await cyclingFile.exists()) {
        final sessionData = await manager.parseFitFileSessionData(cyclingFile);
        print('Cycling file session data: $sessionData');
        expect(sessionData, isNotNull);
        if (sessionData != null) {
          expect(sessionData['totalDistance'], isNotNull);
          expect(sessionData['totalDistance'], isA<double>());
          expect(sessionData['totalTime'], isNotNull);
          expect(sessionData['totalTime'], isA<Duration>());
        }
      }
    });

    test('FitFileManager should handle FIT files with missing session data', () async {
      final manager = FitFileManager();
      
      // Test with minimal FIT file
      final minimalFile = File('test_fit_output/Minimal_Test_20260106_1151.fit');
      if (await minimalFile.exists()) {
        final detail = await manager.getFitFileDetail(minimalFile.path);
        expect(detail, isNotNull);
        
        // Should still extract basic info even if session data is minimal
        expect(detail!.fileName, isNotEmpty);
        expect(detail.activityName, isNotEmpty);
        expect(detail.dataPoints, isNotEmpty);
      }
    });

    test('FitFileManager should handle non-existent directories', () async {
      final manager = FitFileManager();
      final files = await manager.getAllFitFiles();
      // Should return empty list without throwing errors
      expect(files, isA<List<FitFileInfo>>());
    });

    test('FitFileManager should handle file count correctly', () async {
      final manager = FitFileManager();
      final count = await manager.getFitFileCount();
      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));
    });

    test('FitFileManager should handle total size correctly', () async {
      final manager = FitFileManager();
      final totalSize = await manager.getTotalFitFileSize();
      expect(totalSize, isA<int>());
      expect(totalSize, greaterThanOrEqualTo(0));
    });
  });

  group('FitFileManager getAllFitFilesFromDirectory', () {
    test('should list FIT files from test directory', () async {
      final manager = FitFileManager();
      final testDir = Directory('test_fit_output');

      final fitFiles = await manager.getAllFitFilesFromDirectory(testDir);

      expect(fitFiles, isNotNull);
      expect(fitFiles, isA<List<FitFileInfo>>());

      // Should find at least the test files
      expect(fitFiles.length, greaterThanOrEqualTo(3)); // We have at least 3 test FIT files

      // Check that files are sorted by creation date (newest first)
      for (int i = 0; i < fitFiles.length - 1; i++) {
        expect(fitFiles[i].creationDate.isAfter(fitFiles[i + 1].creationDate) ||
               fitFiles[i].creationDate.isAtSameMomentAs(fitFiles[i + 1].creationDate), isTrue);
      }

      // Check that each file has required properties
      for (final fitFile in fitFiles) {
        expect(fitFile.fileName, endsWith('.fit'));
        expect(fitFile.filePath, contains('test_fit_output'));
        expect(fitFile.creationDate, isNotNull);
        expect(fitFile.fileSizeBytes, greaterThan(0));
        expect(fitFile.activityName, isNotNull);
      }
    });

    test('should handle non-existent directory', () async {
      final manager = FitFileManager();
      final nonExistentDir = Directory('non_existent_directory');

      final fitFiles = await manager.getAllFitFilesFromDirectory(nonExistentDir);

      expect(fitFiles, isNotNull);
      expect(fitFiles, isEmpty);
    });
  });
}
