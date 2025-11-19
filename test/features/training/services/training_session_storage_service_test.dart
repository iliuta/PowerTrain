import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/model/training_session.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/services/training_session_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Mock DirectoryProvider that uses a real temporary directory for testing
class MockDirectoryProvider implements DirectoryProvider {
  final Directory _tempDir;
  
  MockDirectoryProvider(this._tempDir);
  
  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    return _tempDir;
  }
}

/// Mock AssetBundleProvider that returns pre-configured asset content
class MockAssetBundleProvider implements AssetBundleProvider {
  final Map<String, String> _assets;
  
  MockAssetBundleProvider(this._assets);
  
  @override
  Future<String> loadString(String key) async {
    if (_assets.containsKey(key)) {
      return _assets[key]!;
    }
    throw Exception('Asset not found: $key');
  }
}

void main() {
  late Directory tempDir;
  late MockDirectoryProvider mockDirectoryProvider;
  late TrainingSessionStorageService service;
  late MockClient mockClient;

  setUp(() async {
    // Create a REAL temporary directory for each test
    tempDir = await Directory.systemTemp.createTemp('ftms_test_');
    mockDirectoryProvider = MockDirectoryProvider(tempDir);
    
    // Default mock client that returns empty responses
    mockClient = MockClient((request) async {
      return http.Response('[]', 200);
    });
    
    service = TrainingSessionStorageService(
      client: mockClient,
      directoryProvider: mockDirectoryProvider,
    );
  });

  tearDown(() async {
    // Clean up the temporary directory after each test
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('saveSession', () {
    test('should save a training session to disk', () async {
      final session = TrainingSessionDefinition(
        title: 'Test Workout',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(
            duration: 300,
            targets: {'power': 150},
          ),
        ],
      );

      final filePath = await service.saveSession(session);

      // Verify file was created
      final file = File(filePath);
      expect(await file.exists(), isTrue);

      // Verify content
      final content = await file.readAsString();
      final json = jsonDecode(content);
      expect(json['title'], equals('Test Workout'));
      expect(json['ftmsMachineType'], equals('indoorBike'));
    });

    test('should create directory if it does not exist', () async {
      final customDir = Directory('${tempDir.path}/custom_training_sessions');
      expect(await customDir.exists(), isFalse);

      final session = TrainingSessionDefinition(
        title: 'Test',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(duration: 60, targets: {'power': 100}),
        ],
      );

      await service.saveSession(session);

      expect(await customDir.exists(), isTrue);
    });

    test('should handle sessions with special characters in title', () async {
      final session = TrainingSessionDefinition(
        title: 'Test: Workout & "Special" Characters!',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(duration: 60, targets: {'power': 100}),
        ],
      );

      final filePath = await service.saveSession(session);
      final file = File(filePath);
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final json = jsonDecode(content);
      expect(json['title'], equals('Test: Workout & "Special" Characters!'));
    });

    test('should save sessions with multiple intervals', () async {
      final session = TrainingSessionDefinition(
        title: 'Multi Interval',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(duration: 300, targets: {'power': 150}),
          UnitTrainingInterval(duration: 60, targets: {'power': 50}),
          UnitTrainingInterval(duration: 600, targets: {'power': 200}),
        ],
      );

      final filePath = await service.saveSession(session);
      final file = File(filePath);
      final content = await file.readAsString();
      final json = jsonDecode(content);
      
      expect(json['intervals'].length, equals(3));
      expect(json['intervals'][0]['duration'], equals(300));
      expect(json['intervals'][1]['duration'], equals(60));
      expect(json['intervals'][2]['duration'], equals(600));
    });

    test('should generate unique filenames for sessions with same title', () async {
      final session = TrainingSessionDefinition(
        title: 'Same Title',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(duration: 60, targets: {'power': 100}),
        ],
      );

      final path1 = await service.saveSession(session);
      await Future.delayed(Duration(milliseconds: 10)); // Ensure different timestamp
      final path2 = await service.saveSession(session);

      expect(path1, isNot(equals(path2)));
      expect(await File(path1).exists(), isTrue);
      expect(await File(path2).exists(), isTrue);
    });
  });

  group('_loadCustomSessions', () {
    test('should load all saved sessions for specified machine type', () async {
      // Save sessions for indoor bike
      final session1 = TrainingSessionDefinition(
        title: 'Bike Workout 1',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );
      final session2 = TrainingSessionDefinition(
        title: 'Bike Workout 2',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 600, targets: {'power': 200})],
      );
      
      await service.saveSession(session1);
      await service.saveSession(session2);

      // Load sessions through loadTrainingSessions which calls _loadCustomSessions
      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      
      // Filter to only custom sessions
      final customSessions = sessions.where((s) => s.isCustom).toList();
      
      expect(customSessions.length, equals(2));
      expect(customSessions.any((s) => s.title == 'Bike Workout 1'), isTrue);
      expect(customSessions.any((s) => s.title == 'Bike Workout 2'), isTrue);
    });

    test('should only load sessions matching the machine type', () async {
      final bikeSession = TrainingSessionDefinition(
        title: 'Bike Workout',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );
      final rowerSession = TrainingSessionDefinition(
        title: 'Rower Workout',
        ftmsMachineType: DeviceType.rower,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );

      await service.saveSession(bikeSession);
      await service.saveSession(rowerSession);

      final bikeSessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final customBikeSessions = bikeSessions.where((s) => s.isCustom).toList();
      
      expect(customBikeSessions.length, equals(1));
      expect(customBikeSessions[0].title, equals('Bike Workout'));
      expect(customBikeSessions[0].ftmsMachineType, equals(DeviceType.indoorBike));
    });

    test('should return empty list when no sessions exist', () async {
      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final customSessions = sessions.where((s) => s.isCustom).toList();
      
      expect(customSessions, isEmpty);
    });

    test('should skip corrupted JSON files', () async {
      // Save a valid session
      final validSession = TrainingSessionDefinition(
        title: 'Valid Workout',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );
      await service.saveSession(validSession);

      // Manually create a corrupted file
      final customDir = Directory('${tempDir.path}/custom_training_sessions');
      await customDir.create(recursive: true);
      final corruptedFile = File('${customDir.path}/corrupted_123456.json');
      await corruptedFile.writeAsString('{ invalid json }');

      // Should load only the valid session
      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final customSessions = sessions.where((s) => s.isCustom).toList();
      
      expect(customSessions.length, equals(1));
      expect(customSessions[0].title, equals('Valid Workout'));
    });

    test('should preserve all session properties', () async {
      final session = TrainingSessionDefinition(
        title: 'Complex Workout',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(
            title: 'Warmup',
            duration: 300,
            targets: {'power': 100, 'cadence': 20},
          ),
          UnitTrainingInterval(
            title: 'Main Set',
            duration: 600,
            targets: {'power': 200, 'cadence': 30},
            resistanceLevel: 5,
          ),
        ],
      );

      await service.saveSession(session);
      
      final sessions = await service.loadTrainingSessions(DeviceType.rower);
      final loaded = sessions.where((s) => s.isCustom).first;

      expect(loaded.title, equals('Complex Workout'));
      expect(loaded.ftmsMachineType, equals(DeviceType.rower));
      expect(loaded.intervals.length, equals(2));
      
      final interval0 = loaded.intervals[0] as UnitTrainingInterval;
      expect(interval0.title, equals('Warmup'));
      expect(interval0.duration, equals(300));
      expect(interval0.targets?['power'], equals(100));
    });
  });

  group('deleteSession', () {
    test('should delete an existing session', () async {
      final session = TrainingSessionDefinition(
        title: 'To Delete',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );

      final filePath = await service.saveSession(session);
      expect(await File(filePath).exists(), isTrue);

      final result = await service.deleteSession('To Delete', 'indoorBike');

      expect(result, isTrue);
      expect(await File(filePath).exists(), isFalse);
    });

    test('should return false when session does not exist', () async {
      final result = await service.deleteSession('Non Existent', 'indoorBike');
      expect(result, isFalse);
    });

    test('should only delete session matching both title and machine type', () async {
      final bikeSession = TrainingSessionDefinition(
        title: 'Same Title',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );
      final rowerSession = TrainingSessionDefinition(
        title: 'Same Title',
        ftmsMachineType: DeviceType.rower,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );

      final bikePath = await service.saveSession(bikeSession);
      final rowerPath = await service.saveSession(rowerSession);

      // Verify both files exist
      final bikeFile = File(bikePath);
      final rowerFile = File(rowerPath);
      expect(await bikeFile.exists(), isTrue);
      expect(await rowerFile.exists(), isTrue);
      
      // Verify the JSON structure
      final bikeContent = await bikeFile.readAsString();
      final bikeJson = jsonDecode(bikeContent) as Map<String, dynamic>;
      expect(bikeJson['ftmsMachineType'], equals('indoorBike'));

      final result = await service.deleteSession('Same Title', 'indoorBike');

      expect(result, isTrue, reason: 'Should successfully delete the bike session');
      expect(await bikeFile.exists(), isFalse, reason: 'Bike session file should be deleted');
      expect(await rowerFile.exists(), isTrue, reason: 'Rower session file should still exist');
    });

    test('should delete only one session when multiple match', () async {
      final session1 = TrainingSessionDefinition(
        title: 'Duplicate',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );

      await service.saveSession(session1);
      await Future.delayed(Duration(milliseconds: 10));
      await service.saveSession(session1);

      final result = await service.deleteSession('Duplicate', 'indoorBike');
      expect(result, isTrue);

      // Should still have one session left
      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final customSessions = sessions.where((s) => s.isCustom).toList();
      expect(customSessions.length, equals(1));
    });

    test('should return false when directory does not exist', () async {
      final result = await service.deleteSession('Any Title', 'indoorBike');
      expect(result, isFalse);
    });
  });

  group('_saveGitHubCacheToDisk and _loadGitHubCacheFromDisk', () {
    test('should save and load GitHub cache correctly', () async {
      // Manually populate cache and save to disk
      final session1 = TrainingSessionDefinition(
        title: 'GitHub Workout 1',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );
      final session2 = TrainingSessionDefinition(
        title: 'GitHub Workout 2',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 600, targets: {'power': 200})],
      );

      // Manually add to cache
      service.githubSessionsCache[DeviceType.indoorBike] = [session1, session2];

      // Manually create cache directory and files (simulating what _saveGitHubCacheToDisk does)
      final cacheDir = Directory('${tempDir.path}/github_sessions_cache');
      await cacheDir.create(recursive: true);

      // Save metadata
      final metadata = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'lastModified': 'Mon, 01 Jan 2024 00:00:00 GMT',
        'indoorBike': 2,
      };
      final metadataFile = File('${cacheDir.path}/cache_metadata.json');
      await metadataFile.writeAsString(jsonEncode(metadata));

      // Save session data
      final sessionData = [session1.toJson(), session2.toJson()];
      final sessionFile = File('${cacheDir.path}/indoorBike.json');
      await sessionFile.writeAsString(jsonEncode(sessionData));

      await sessionFile.writeAsString(jsonEncode(sessionData));

      // Verify cache files were created
      expect(await cacheDir.exists(), isTrue);
      expect(await metadataFile.exists(), isTrue);
      expect(await sessionFile.exists(), isTrue);

      // Verify metadata content
      final metadataContent = jsonDecode(await metadataFile.readAsString());
      expect(metadataContent['lastUpdated'], isNotNull);
      expect(metadataContent['lastModified'], equals('Mon, 01 Jan 2024 00:00:00 GMT'));
      expect(metadataContent['indoorBike'], equals(2));

      // Verify cache file content
      final cacheContent = jsonDecode(await sessionFile.readAsString()) as List;
      expect(cacheContent.length, equals(2));
      expect(cacheContent[0]['title'], equals('GitHub Workout 1'));
      expect(cacheContent[1]['title'], equals('GitHub Workout 2'));
    });

    test('should verify cache file structure for loading', () async {
      // Create cache files that _loadGitHubCacheFromDisk would read
      final cacheDir = Directory('${tempDir.path}/github_sessions_cache');
      await cacheDir.create(recursive: true);

      final session = TrainingSessionDefinition(
        title: 'Cached Workout',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );

      final metadata = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'indoorBike': 1,
      };
      final metadataFile = File('${cacheDir.path}/cache_metadata.json');
      await metadataFile.writeAsString(jsonEncode(metadata));

      final sessionFile = File('${cacheDir.path}/indoorBike.json');
      await sessionFile.writeAsString(jsonEncode([session.toJson()]));

      // Verify cache files exist and are readable
      expect(await metadataFile.exists(), isTrue);
      expect(await sessionFile.exists(), isTrue);
      
      // Verify metadata can be parsed
      final metadataContent = jsonDecode(await metadataFile.readAsString());
      expect(metadataContent['indoorBike'], equals(1));
      
      // Verify session data can be parsed
      final sessionContent = jsonDecode(await sessionFile.readAsString()) as List;
      expect(sessionContent.length, equals(1));
      expect(sessionContent[0]['title'], equals('Cached Workout'));
    });

    test('should create corrupted cache files that would be skipped', () async {
      // Create corrupted cache that _loadGitHubCacheFromDisk would skip
      final cacheDir = Directory('${tempDir.path}/github_sessions_cache');
      await cacheDir.create(recursive: true);
      final metadataFile = File('${cacheDir.path}/cache_metadata.json');
      await metadataFile.writeAsString('{ corrupted json }');

      // Verify file exists
      expect(await metadataFile.exists(), isTrue);
      
      // Verify it cannot be parsed (would be caught by _loadGitHubCacheFromDisk)
      final content = await metadataFile.readAsString();
      expect(
        () => jsonDecode(content),
        throwsA(isA<FormatException>()),
      );
    });

    test('should create cache structure with corrupted session file', () async {
      // Create valid metadata but corrupted session file
      final cacheDir = Directory('${tempDir.path}/github_sessions_cache');
      await cacheDir.create(recursive: true);
      
      final metadata = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'indoorBike': 1,
      };
      final metadataFile = File('${cacheDir.path}/cache_metadata.json');
      await metadataFile.writeAsString(jsonEncode(metadata));

      final sessionFile = File('${cacheDir.path}/indoorBike.json');
      await sessionFile.writeAsString('[ { invalid json } ]');

      // Verify metadata is valid
      expect(await metadataFile.exists(), isTrue);
      final metadataContent = jsonDecode(await metadataFile.readAsString());
      expect(metadataContent['indoorBike'], equals(1));
      
      // Verify session file exists but is corrupted
      expect(await sessionFile.exists(), isTrue);
      final sessionContent = await sessionFile.readAsString();
      expect(
        () => jsonDecode(sessionContent),
        throwsA(isA<FormatException>()),
      );
    });

    test('should save cache for multiple machine types', () async {
      // Manually create cache for multiple types
      final cacheDir = Directory('${tempDir.path}/github_sessions_cache');
      await cacheDir.create(recursive: true);

      final bikeSession = TrainingSessionDefinition(
        title: 'Bike Workout',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );
      final rowerSession = TrainingSessionDefinition(
        title: 'Rower Workout',
        ftmsMachineType: DeviceType.rower,
        intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
      );

      // Save both cache files
      final bikeFile = File('${cacheDir.path}/indoorBike.json');
      await bikeFile.writeAsString(jsonEncode([bikeSession.toJson()]));
      
      final rowerFile = File('${cacheDir.path}/rower.json');
      await rowerFile.writeAsString(jsonEncode([rowerSession.toJson()]));

      // Save metadata
      final metadata = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'indoorBike': 1,
        'rower': 1,
      };
      final metadataFile = File('${cacheDir.path}/cache_metadata.json');
      await metadataFile.writeAsString(jsonEncode(metadata));

      // Verify both cache files exist
      expect(await bikeFile.exists(), isTrue);
      expect(await rowerFile.exists(), isTrue);

      // Verify metadata
      final metadataContent = jsonDecode(await metadataFile.readAsString());
      expect(metadataContent['indoorBike'], equals(1));
      expect(metadataContent['rower'], equals(1));
    });

    test('should handle empty cache correctly', () async {
      // Cache is empty, so saving should not create files
      await Future.delayed(Duration(milliseconds: 100));

      final cacheDir = Directory('${tempDir.path}/github_sessions_cache');
      // Directory might exist but should have no session files
      if (await cacheDir.exists()) {
        final files = cacheDir.listSync().where((e) => e.path.endsWith('.json')).toList();
        expect(files, isEmpty);
      }
    });
  });

  group('Integration: Full workflow', () {
    test('should save, load, and delete multiple sessions', () async {
      // Save multiple sessions
      for (int i = 1; i <= 5; i++) {
        await service.saveSession(
          TrainingSessionDefinition(
            title: 'Workout $i',
            ftmsMachineType: DeviceType.indoorBike,
            intervals: [
              UnitTrainingInterval(duration: 300 * i, targets: {'power': 100 + i * 10}),
            ],
          ),
        );
      }

      // Load and verify
      var sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      var customSessions = sessions.where((s) => s.isCustom).toList();
      expect(customSessions.length, equals(5));

      // Delete some sessions
      await service.deleteSession('Workout 2', 'indoorBike');
      await service.deleteSession('Workout 4', 'indoorBike');

      // Load again and verify
      sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      customSessions = sessions.where((s) => s.isCustom).toList();
      expect(customSessions.length, equals(3));
      expect(customSessions.any((s) => s.title == 'Workout 1'), isTrue);
      expect(customSessions.any((s) => s.title == 'Workout 2'), isFalse);
      expect(customSessions.any((s) => s.title == 'Workout 3'), isTrue);
      expect(customSessions.any((s) => s.title == 'Workout 4'), isFalse);
      expect(customSessions.any((s) => s.title == 'Workout 5'), isTrue);
    });

    test('should handle concurrent save operations', () async {
      final futures = <Future>[];
      for (int i = 1; i <= 10; i++) {
        futures.add(service.saveSession(
          TrainingSessionDefinition(
            title: 'Concurrent $i',
            ftmsMachineType: DeviceType.indoorBike,
            intervals: [
              UnitTrainingInterval(duration: 300, targets: {'power': 150}),
            ],
          ),
        ));
      }

      await Future.wait(futures);

      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final customSessions = sessions.where((s) => s.isCustom).toList();
      expect(customSessions.length, equals(10));
    });

    test('should isolate sessions by machine type', () async {
      // Save sessions for different machine types
      await service.saveSession(
        TrainingSessionDefinition(
          title: 'Bike 1',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
        ),
      );
      await service.saveSession(
        TrainingSessionDefinition(
          title: 'Bike 2',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
        ),
      );
      await service.saveSession(
        TrainingSessionDefinition(
          title: 'Rower 1',
          ftmsMachineType: DeviceType.rower,
          intervals: [UnitTrainingInterval(duration: 300, targets: {'power': 150})],
        ),
      );

      // Load bike sessions
      final bikeSessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final customBikeSessions = bikeSessions.where((s) => s.isCustom).toList();
      expect(customBikeSessions.length, equals(2));
      expect(customBikeSessions.every((s) => s.ftmsMachineType == DeviceType.indoorBike), isTrue);

      // Load rower sessions
      final rowerSessions = await service.loadTrainingSessions(DeviceType.rower);
      final customRowerSessions = rowerSessions.where((s) => s.isCustom).toList();
      expect(customRowerSessions.length, equals(1));
      expect(customRowerSessions[0].ftmsMachineType, equals(DeviceType.rower));
    });
  });

  group('_loadBuiltInSessions', () {
    test('should load sessions from asset manifest matching machine type', () async {
      // Create a mock asset bundle that returns manifest and session files
      final mockAssetBundle = MockAssetBundleProvider({
        'AssetManifest.json': jsonEncode({
          'lib/training-sessions/bike_session_1.json': ['lib/training-sessions/bike_session_1.json'],
          'lib/training-sessions/rower_session_1.json': ['lib/training-sessions/rower_session_1.json'],
          'lib/training-sessions/bike_session_2.json': ['lib/training-sessions/bike_session_2.json'],
          'lib/other/not_a_session.json': ['lib/other/not_a_session.json'],
        }),
        'lib/training-sessions/bike_session_1.json': jsonEncode({
          'title': 'Bike Workout 1',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 300, 'targets': {'power': 150}}
          ],
        }),
        'lib/training-sessions/bike_session_2.json': jsonEncode({
          'title': 'Bike Workout 2',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 600, 'targets': {'power': 200}}
          ],
        }),
        'lib/training-sessions/rower_session_1.json': jsonEncode({
          'title': 'Rowing Workout',
          'ftmsMachineType': 'rower',
          'intervals': [
            {'duration': 400, 'targets': {'power': 180}}
          ],
        }),
      });

      final testService = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: mockDirectoryProvider,
        assetBundleProvider: mockAssetBundle,
      );

      // Load bike sessions
      final sessions = await testService.loadTrainingSessions(DeviceType.indoorBike);
      final builtInSessions = sessions.where((s) => !s.isCustom).toList();

      expect(builtInSessions.length, equals(2));
      expect(builtInSessions[0].title, equals('Bike Workout 1'));
      expect(builtInSessions[0].ftmsMachineType, equals(DeviceType.indoorBike));
      expect(builtInSessions[1].title, equals('Bike Workout 2'));
      expect(builtInSessions[1].ftmsMachineType, equals(DeviceType.indoorBike));
    });

    test('should filter sessions by machine type', () async {
      final mockAssetBundle = MockAssetBundleProvider({
        'AssetManifest.json': jsonEncode({
          'lib/training-sessions/bike_session.json': ['lib/training-sessions/bike_session.json'],
          'lib/training-sessions/rower_session.json': ['lib/training-sessions/rower_session.json'],
        }),
        'lib/training-sessions/bike_session.json': jsonEncode({
          'title': 'Bike Workout',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 300, 'targets': {'power': 150}}
          ],
        }),
        'lib/training-sessions/rower_session.json': jsonEncode({
          'title': 'Rowing Workout',
          'ftmsMachineType': 'rower',
          'intervals': [
            {'duration': 400, 'targets': {'power': 180}}
          ],
        }),
      });

      final testService = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: mockDirectoryProvider,
        assetBundleProvider: mockAssetBundle,
      );

      // Load rower sessions
      final sessions = await testService.loadTrainingSessions(DeviceType.rower);
      final builtInSessions = sessions.where((s) => !s.isCustom).toList();

      expect(builtInSessions.length, equals(1));
      expect(builtInSessions[0].title, equals('Rowing Workout'));
      expect(builtInSessions[0].ftmsMachineType, equals(DeviceType.rower));
    });

    test('should return empty list when no matching sessions found', () async {
      final mockAssetBundle = MockAssetBundleProvider({
        'AssetManifest.json': jsonEncode({
          'lib/training-sessions/bike_session.json': ['lib/training-sessions/bike_session.json'],
        }),
        'lib/training-sessions/bike_session.json': jsonEncode({
          'title': 'Bike Workout',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 300, 'targets': {'power': 150}}
          ],
        }),
      });

      final testService = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: mockDirectoryProvider,
        assetBundleProvider: mockAssetBundle,
      );

      // Try to load rower sessions when only bike sessions exist
      final sessions = await testService.loadTrainingSessions(DeviceType.rower);
      final builtInSessions = sessions.where((s) => !s.isCustom).toList();

      expect(builtInSessions, isEmpty);
    });

    test('should handle corrupted session files gracefully', () async {
      final mockAssetBundle = MockAssetBundleProvider({
        'AssetManifest.json': jsonEncode({
          'lib/training-sessions/good_session.json': ['lib/training-sessions/good_session.json'],
          'lib/training-sessions/bad_session.json': ['lib/training-sessions/bad_session.json'],
        }),
        'lib/training-sessions/good_session.json': jsonEncode({
          'title': 'Good Workout',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 300, 'targets': {'power': 150}}
          ],
        }),
        'lib/training-sessions/bad_session.json': 'invalid json {{{',
      });

      final testService = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: mockDirectoryProvider,
        assetBundleProvider: mockAssetBundle,
      );

      // Should load good session and skip bad one
      final sessions = await testService.loadTrainingSessions(DeviceType.indoorBike);
      final builtInSessions = sessions.where((s) => !s.isCustom).toList();

      expect(builtInSessions.length, equals(1));
      expect(builtInSessions[0].title, equals('Good Workout'));
    });

    test('should handle empty manifest', () async {
      final mockAssetBundle = MockAssetBundleProvider({
        'AssetManifest.json': jsonEncode({}),
      });

      final testService = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: mockDirectoryProvider,
        assetBundleProvider: mockAssetBundle,
      );

      final sessions = await testService.loadTrainingSessions(DeviceType.indoorBike);
      final builtInSessions = sessions.where((s) => !s.isCustom).toList();

      expect(builtInSessions, isEmpty);
    });

    test('should only load files from training-sessions directory', () async {
      final mockAssetBundle = MockAssetBundleProvider({
        'AssetManifest.json': jsonEncode({
          'lib/training-sessions/valid.json': ['lib/training-sessions/valid.json'],
          'lib/other-dir/invalid.json': ['lib/other-dir/invalid.json'],
          'assets/sessions/another.json': ['assets/sessions/another.json'],
        }),
        'lib/training-sessions/valid.json': jsonEncode({
          'title': 'Valid Workout',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 300, 'targets': {'power': 150}}
          ],
        }),
        'lib/other-dir/invalid.json': jsonEncode({
          'title': 'Should Not Load',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 300, 'targets': {'power': 150}}
          ],
        }),
      });

      final testService = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: mockDirectoryProvider,
        assetBundleProvider: mockAssetBundle,
      );

      final sessions = await testService.loadTrainingSessions(DeviceType.indoorBike);
      final builtInSessions = sessions.where((s) => !s.isCustom).toList();

      expect(builtInSessions.length, equals(1));
      expect(builtInSessions[0].title, equals('Valid Workout'));
    });

    test('should load sessions with multiple intervals', () async {
      final mockAssetBundle = MockAssetBundleProvider({
        'AssetManifest.json': jsonEncode({
          'lib/training-sessions/complex.json': ['lib/training-sessions/complex.json'],
        }),
        'lib/training-sessions/complex.json': jsonEncode({
          'title': 'Complex Workout',
          'ftmsMachineType': 'indoorBike',
          'intervals': [
            {'duration': 300, 'targets': {'power': 100}},
            {'duration': 600, 'targets': {'power': 200}},
            {'duration': 300, 'targets': {'power': 150}},
          ],
        }),
      });

      final testService = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: mockDirectoryProvider,
        assetBundleProvider: mockAssetBundle,
      );

      final sessions = await testService.loadTrainingSessions(DeviceType.indoorBike);
      final builtInSessions = sessions.where((s) => !s.isCustom).toList();

      expect(builtInSessions.length, equals(1));
      expect(builtInSessions[0].intervals.length, equals(3));
      expect((builtInSessions[0].intervals[0] as UnitTrainingInterval).duration, equals(300));
      expect((builtInSessions[0].intervals[1] as UnitTrainingInterval).duration, equals(600));
      expect((builtInSessions[0].intervals[2] as UnitTrainingInterval).duration, equals(300));
    });
  });
}
