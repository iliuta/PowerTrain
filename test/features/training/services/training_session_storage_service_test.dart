import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:ftms/features/training/services/training_session_storage_service.dart';
import 'package:ftms/features/training/model/training_session.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/core/models/device_types.dart';

import 'training_session_storage_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrainingSessionStorageService - loadTrainingSessions', () {
    late Directory tempDir;
    late _TestDirectoryProvider directoryProvider;
    late MockClient mockClient;

    setUp(() async {
      // Create a temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('training_session_test_');
      directoryProvider = _TestDirectoryProvider(tempDir);
      mockClient = MockClient();
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'loads built-in, GitHub, and custom sessions correctly for rower and bike with caching',
        () async {
      // Setup custom sessions directory and files
      final customSessionsDir =
          Directory('${tempDir.path}/custom_training_sessions');
      await customSessionsDir.create(recursive: true);

      // Create custom rower session file
      final customRowerSession = {
        'title': 'Custom Rower Session',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'Custom Interval',
            'duration': 300,
            'targets': {'Instantaneous Pace': '90%', 'Stroke Rate': 22.0},
            'resistanceLevel': 50,
            'repeat': 1
          }
        ]
      };
      final customRowerFile =
          File('${customSessionsDir.path}/custom_rower.json');
      await customRowerFile
          .writeAsString(jsonEncode(customRowerSession), encoding: utf8);

      // Create custom bike session file
      final customBikeSession = {
        'title': 'Custom Bike Session',
        'ftmsMachineType': 'indoorBike',
        'intervals': [
          {
            'title': 'Custom Bike Interval',
            'duration': 300,
            'targets': {
              'Instantaneous Power': '85%',
              'Instantaneous Cadence': 90
            },
            'repeat': 1
          }
        ]
      };
      final customBikeFile =
          File('${customSessionsDir.path}/custom_bike.json');
      await customBikeFile
          .writeAsString(jsonEncode(customBikeSession), encoding: utf8);

      // Mock GitHub API responses (ONLY mock HTTP, everything else is real)
      final githubRowerSession1 = {
        'title': 'GitHub Rower Session 1',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'GitHub Interval 1',
            'duration': 600,
            'targets': {'Instantaneous Pace': '92%', 'Stroke Rate': 24.0},
            'resistanceLevel': 55,
            'repeat': 1
          }
        ]
      };

      final githubRowerSession2 = {
        'title': 'GitHub Rower Session 2',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'GitHub Interval 2',
            'duration': 700,
            'targets': {'Instantaneous Pace': '94%', 'Stroke Rate': 26.0},
            'resistanceLevel': 60,
            'repeat': 1
          }
        ]
      };

      final githubRowerSession3 = {
        'title': 'GitHub Rower Session 3',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'GitHub Interval 3',
            'duration': 800,
            'targets': {'Instantaneous Pace': '96%', 'Stroke Rate': 28.0},
            'resistanceLevel': 65,
            'repeat': 1
          }
        ]
      };

      final githubBikeSession = {
        'title': 'GitHub Bike Session',
        'ftmsMachineType': 'indoorBike',
        'intervals': [
          {
            'title': 'GitHub Bike Interval',
            'duration': 900,
            'targets': {'Instantaneous Power': '88%', 'Instantaneous Cadence': 95},
            'repeat': 1
          }
        ]
      };

      // Mock GitHub API response
      final githubFiles = [
        {
          'name': 'github_rower_1.json',
          'type': 'file',
          'download_url': 'https://example.com/rower1.json'
        },
        {
          'name': 'github_rower_2.json',
          'type': 'file',
          'download_url': 'https://example.com/rower2.json'
        },
        {
          'name': 'github_rower_3.json',
          'type': 'file',
          'download_url': 'https://example.com/rower3.json'
        },
        {
          'name': 'github_bike_1.json',
          'type': 'file',
          'download_url': 'https://example.com/bike1.json'
        },
      ];

      when(mockClient.get(Uri.parse(
              'https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions')))
          .thenAnswer((_) async => http.Response(
                jsonEncode(githubFiles),
                200,
                headers: {'last-modified': 'Wed, 22 Nov 2023 12:00:00 GMT'},
              ));

      when(mockClient.get(Uri.parse('https://example.com/rower1.json')))
          .thenAnswer((_) async =>
              http.Response(jsonEncode(githubRowerSession1), 200));
      when(mockClient.get(Uri.parse('https://example.com/rower2.json')))
          .thenAnswer((_) async =>
              http.Response(jsonEncode(githubRowerSession2), 200));
      when(mockClient.get(Uri.parse('https://example.com/rower3.json')))
          .thenAnswer((_) async =>
              http.Response(jsonEncode(githubRowerSession3), 200));
      when(mockClient.get(Uri.parse('https://example.com/bike1.json')))
          .thenAnswer((_) async =>
              http.Response(jsonEncode(githubBikeSession), 200));

      // Create service instance (no AssetBundleProvider - use real assets)
      final service = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: directoryProvider,
      );

      // WHEN: Load training sessions for rower (first time)
      final rowerSessionsFirstCall =
          await service.loadTrainingSessions(DeviceType.rower);

      // THEN: Verify rower sessions content (first call)
      // Built-in: 5 rower sessions (2k_steady, 30x30, steady-35-min, steady_state_endurance_base, test-session)
      // GitHub: 4 rower+bike sessions (3 rower, bike filtered later)
      // Custom: 1 rower session
      expect(rowerSessionsFirstCall.length, 5,
          reason: '1 built-in + 4 GitHub + 1 custom for rower');

      // Verify GitHub sessions are present
      final githubRower1 = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Rower Session 1');
      expect(githubRower1.ftmsMachineType, DeviceType.rower);
      expect(githubRower1.isCustom, false);

      final githubRower2 = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Rower Session 2');
      expect(githubRower2.ftmsMachineType, DeviceType.rower);
      expect(githubRower2.isCustom, false);

      final githubRower3 = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Rower Session 3');
      expect(githubRower3.ftmsMachineType, DeviceType.rower);
      expect(githubRower3.isCustom, false);

      // Verify custom session
      final customRower = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'Custom Rower Session');
      expect(customRower.ftmsMachineType, DeviceType.rower);
      expect(customRower.isCustom, true);

      // Verify at least one built-in session
      final testSession = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'Test session 1min30s');
      expect(testSession.ftmsMachineType, DeviceType.rower);
      expect(testSession.isCustom, false);

      // VERIFY: GitHub cache files were created on disk
      final githubCacheDir = Directory('${tempDir.path}/github_sessions_cache');
      expect(await githubCacheDir.exists(), true,
          reason: 'GitHub cache directory should be created');

      final githubCacheFile = File('${githubCacheDir.path}/github-cache.json');
      expect(await githubCacheFile.exists(), true,
          reason: 'GitHub cache file should be created');

      final cacheMetadataFile = File('${githubCacheDir.path}/cache_metadata.json');
      expect(await cacheMetadataFile.exists(), true,
          reason: 'Cache metadata file should be created');

      // Verify cache file content
      final cacheContent = await githubCacheFile.readAsString(encoding: utf8);
      final cachedSessions = jsonDecode(cacheContent) as List<dynamic>;
      expect(cachedSessions.length, 4,
          reason: 'Should cache all 4 GitHub sessions (3 rower + 1 bike)');

      // Verify metadata content
      final metadataContent = await cacheMetadataFile.readAsString(encoding: utf8);
      final metadata = jsonDecode(metadataContent) as Map<String, dynamic>;
      expect(metadata['lastModified'], 'Wed, 22 Nov 2023 12:00:00 GMT',
          reason: 'Should store Last-Modified header');
      expect(metadata['lastUpdated'], isNotNull,
          reason: 'Should store timestamp');

      // WHEN: Load training sessions for rower (second time - should use cache)
      final rowerSessionsSecondCall =
          await service.loadTrainingSessions(DeviceType.rower);

      // THEN: Verify rower sessions content (second call, from cache)
      expect(rowerSessionsSecondCall.length, 5,
          reason: '1 built-in + 3 GitHub (cached) + 1 custom for rower');

      expect(
          rowerSessionsSecondCall
              .where((s) => s.title == 'Test session 1min30s')
              .length,
          1);
      expect(
          rowerSessionsSecondCall
              .where((s) => s.title == 'GitHub Rower Session 1')
              .length,
          1);
      expect(
          rowerSessionsSecondCall
              .where((s) => s.title == 'GitHub Rower Session 2')
              .length,
          1);
      expect(
          rowerSessionsSecondCall
              .where((s) => s.title == 'GitHub Rower Session 3')
              .length,
          1);
      expect(
          rowerSessionsSecondCall
              .where((s) => s.title == 'Custom Rower Session')
              .length,
          1);

      // WHEN: Load training sessions for bike (first time)
      final bikeSessionsFirstCall =
          await service.loadTrainingSessions(DeviceType.indoorBike);

      // THEN: Verify bike sessions content (first call)
      // Built-in: 2 bike sessions (16min-test, distance-test)
      // GitHub: 1 bike session
      // Custom: 1 bike session
      expect(bikeSessionsFirstCall.length, 4,
          reason: '2 built-in + 1 GitHub + 1 custom for bike');

      final githubBike = bikeSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Bike Session');
      expect(githubBike.ftmsMachineType, DeviceType.indoorBike);
      expect(githubBike.isCustom, false);

      final customBike = bikeSessionsFirstCall
          .firstWhere((s) => s.title == 'Custom Bike Session');
      expect(customBike.ftmsMachineType, DeviceType.indoorBike);
      expect(customBike.isCustom, true);

      // Verify at least one built-in bike session
      final enduranceRide = bikeSessionsFirstCall
          .firstWhere((s) => s.title == 'Test session 16min');
      expect(enduranceRide.ftmsMachineType, DeviceType.indoorBike);
      expect(enduranceRide.isCustom, false);

      // WHEN: Load training sessions for bike (second time - should use cache)
      final bikeSessionsSecondCall =
          await service.loadTrainingSessions(DeviceType.indoorBike);

      // THEN: Verify bike sessions content (second call, from cache)
      expect(bikeSessionsSecondCall.length, 4,
          reason: '2 built-in + 1 GitHub (cached) + 1 custom for bike');

      expect(
          bikeSessionsSecondCall
              .where((s) => s.title == 'GitHub Bike Session')
              .length,
          1);
      expect(
          bikeSessionsSecondCall
              .where((s) => s.title == 'Custom Bike Session')
              .length,
          1);

      // Verify GitHub API was called once per device type (rower and bike)
      // The service downloads GitHub sessions on first access per device type
      verify(mockClient.get(Uri.parse(
              'https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions')))
          .called(2); // Once for rower, once for bike
    });

    test(
        'loads sessions from disk cache when GitHub cache exists but memory cache is empty',
        () async {
      // Setup custom sessions directory and files
      final customSessionsDir =
          Directory('${tempDir.path}/custom_training_sessions');
      await customSessionsDir.create(recursive: true);

      // Create custom rower session file
      final customRowerSession = {
        'title': 'Custom Rower Session',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'Custom Interval',
            'duration': 300,
            'targets': {'Instantaneous Pace': '90%', 'Stroke Rate': 22.0},
            'resistanceLevel': 50,
            'repeat': 1
          }
        ]
      };
      final customRowerFile =
          File('${customSessionsDir.path}/custom_rower.json');
      await customRowerFile
          .writeAsString(jsonEncode(customRowerSession), encoding: utf8);

      // Create custom bike session file
      final customBikeSession = {
        'title': 'Custom Bike Session',
        'ftmsMachineType': 'indoorBike',
        'intervals': [
          {
            'title': 'Custom Bike Interval',
            'duration': 300,
            'targets': {
              'Instantaneous Power': '85%',
              'Instantaneous Cadence': 90
            },
            'repeat': 1
          }
        ]
      };
      final customBikeFile =
          File('${customSessionsDir.path}/custom_bike.json');
      await customBikeFile
          .writeAsString(jsonEncode(customBikeSession), encoding: utf8);

      // Pre-create GitHub cache on disk (simulating previous app session)
      final githubCacheDir = Directory('${tempDir.path}/github_sessions_cache');
      await githubCacheDir.create(recursive: true);

      final githubRowerSession1 = {
        'title': 'GitHub Rower Session 1',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'GitHub Interval 1',
            'duration': 600,
            'targets': {'Instantaneous Pace': '92%', 'Stroke Rate': 24.0},
            'resistanceLevel': 55,
            'repeat': 1
          }
        ]
      };

      final githubRowerSession2 = {
        'title': 'GitHub Rower Session 2',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'GitHub Interval 2',
            'duration': 700,
            'targets': {'Instantaneous Pace': '94%', 'Stroke Rate': 26.0},
            'resistanceLevel': 60,
            'repeat': 1
          }
        ]
      };

      final githubRowerSession3 = {
        'title': 'GitHub Rower Session 3',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'GitHub Interval 3',
            'duration': 800,
            'targets': {'Instantaneous Pace': '96%', 'Stroke Rate': 28.0},
            'resistanceLevel': 65,
            'repeat': 1
          }
        ]
      };

      final githubBikeSession = {
        'title': 'GitHub Bike Session',
        'ftmsMachineType': 'indoorBike',
        'intervals': [
          {
            'title': 'GitHub Bike Interval',
            'duration': 900,
            'targets': {'Instantaneous Power': '88%', 'Instantaneous Cadence': 95},
            'repeat': 1
          }
        ]
      };

      // Write GitHub cache to disk
      final githubCacheFile = File('${githubCacheDir.path}/github-cache.json');
      final cachedSessions = [
        githubRowerSession1,
        githubRowerSession2,
        githubRowerSession3,
        githubBikeSession,
      ];
      await githubCacheFile.writeAsString(jsonEncode(cachedSessions), encoding: utf8);

      // Write cache metadata
      final cacheMetadataFile = File('${githubCacheDir.path}/cache_metadata.json');
      final metadata = {
        'lastModified': 'Wed, 22 Nov 2023 12:00:00 GMT',
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await cacheMetadataFile.writeAsString(jsonEncode(metadata), encoding: utf8);

      // Mock GitHub API to return matching Last-Modified (indicating cache is up-to-date)
      // The service will check GitHub to validate cache freshness, find it's up-to-date, and use disk cache
      // This simulates the scenario where cache exists and is still fresh
      when(mockClient.get(Uri.parse(
              'https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions')))
          .thenAnswer((_) async => http.Response(
                jsonEncode([]),
                200,
                headers: {'last-modified': 'Wed, 22 Nov 2023 12:00:00 GMT'},
              ));

      // Create service instance (no in-memory cache)
      final service = TrainingSessionStorageService(
        client: mockClient,
        directoryProvider: directoryProvider,
      );

      // WHEN: Load training sessions for rower (first time - should load from disk cache)
      final rowerSessionsFirstCall =
          await service.loadTrainingSessions(DeviceType.rower);

      // THEN: Verify rower sessions loaded from disk cache
      // Built-in: 5 rower sessions
      // GitHub: 3 rower sessions (from disk cache, filtered)
      // Custom: 1 rower session
      expect(rowerSessionsFirstCall.length, 5,
          reason: '1 built-in + 3 GitHub (from disk cache) + 1 custom for rower');

      // Verify GitHub sessions are present
      final githubRower1 = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Rower Session 1');
      expect(githubRower1.ftmsMachineType, DeviceType.rower);
      expect(githubRower1.isCustom, false);

      final githubRower2 = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Rower Session 2');
      expect(githubRower2.ftmsMachineType, DeviceType.rower);
      expect(githubRower2.isCustom, false);

      final githubRower3 = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Rower Session 3');
      expect(githubRower3.ftmsMachineType, DeviceType.rower);
      expect(githubRower3.isCustom, false);

      // Verify custom session
      final customRower = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'Custom Rower Session');
      expect(customRower.ftmsMachineType, DeviceType.rower);
      expect(customRower.isCustom, true);

      // Verify at least one built-in session
      final testSession = rowerSessionsFirstCall
          .firstWhere((s) => s.title == 'Test session 1min30s');
      expect(testSession.ftmsMachineType, DeviceType.rower);
      expect(testSession.isCustom, false);

      // WHEN: Load training sessions for rower (second time - should use memory cache)
      final rowerSessionsSecondCall =
          await service.loadTrainingSessions(DeviceType.rower);

      // THEN: Verify same results from memory cache
      expect(rowerSessionsSecondCall.length, 5,
          reason: '1 built-in + 3 GitHub (from memory cache) + 1 custom for rower');

      // WHEN: Load training sessions for bike (first time - should load from disk cache)
      final bikeSessionsFirstCall =
          await service.loadTrainingSessions(DeviceType.indoorBike);

      // THEN: Verify bike sessions loaded from disk cache
      // Built-in: 2 bike sessions
      // GitHub: 1 bike session (from disk cache, filtered)
      // Custom: 1 bike session
      expect(bikeSessionsFirstCall.length, 4,
          reason: '2 built-in + 1 GitHub (from disk cache) + 1 custom for bike');

      final githubBike = bikeSessionsFirstCall
          .firstWhere((s) => s.title == 'GitHub Bike Session');
      expect(githubBike.ftmsMachineType, DeviceType.indoorBike);
      expect(githubBike.isCustom, false);

      final customBike = bikeSessionsFirstCall
          .firstWhere((s) => s.title == 'Custom Bike Session');
      expect(customBike.ftmsMachineType, DeviceType.indoorBike);
      expect(customBike.isCustom, true);

      // Verify at least one built-in bike session
      final enduranceRide = bikeSessionsFirstCall
          .firstWhere((s) => s.title == 'Test session 16min');
      expect(enduranceRide.ftmsMachineType, DeviceType.indoorBike);
      expect(enduranceRide.isCustom, false);

      // WHEN: Load training sessions for bike (second time - should use memory cache)
      final bikeSessionsSecondCall =
          await service.loadTrainingSessions(DeviceType.indoorBike);

      // THEN: Verify same results from memory cache
      expect(bikeSessionsSecondCall.length, 4,
          reason: '2 built-in + 1 GitHub (from memory cache) + 1 custom for bike');

      // Verify HTTP was called to validate cache freshness (checking Last-Modified header)
      // The service always validates cache by checking GitHub, even when loading from disk
      // This prevents using stale cache data
      verify(mockClient.get(
        Uri.parse('https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions'),
        headers: null,
      )).called(2); // Once for rower, once for bike
    });
  });

  group('saveSession', () {
    late TrainingSessionStorageService testService;
    late Directory testTempDir;
    late MockClient testMockClient;

    setUp(() async {
      // Create a separate temp directory for saveSession tests
      testTempDir = await Directory.systemTemp.createTemp('save_session_test_');
      testMockClient = MockClient();
      testService = TrainingSessionStorageService(
        client: testMockClient,
        directoryProvider: _TestDirectoryProvider(testTempDir),
      );
    });

    tearDown(() async {
      // Clean up test directory
      if (await testTempDir.exists()) {
        await testTempDir.delete(recursive: true);
      }
    });

    test('saves a new session to disk with correct filename and content', () async {
      // Given: A new training session to save
      final sessionToSave = TrainingSessionDefinition(
        title: 'Test Custom Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(
            title: 'Interval 1',
            duration: 300,
            targets: {'Instantaneous Power': 150},
          ),
          UnitTrainingInterval(
            title: 'Interval 2',
            duration: 60,
            targets: {'Instantaneous Power': 100},
          ),
        ],
        isCustom: true,
      );

      // When: Saving the session
      final savedPath = await testService.saveSession(sessionToSave);

      // Then: File should exist
      final savedFile = File(savedPath);
      expect(savedFile.existsSync(), isTrue);

      // Then: Filename should follow the pattern: safe_title_timestamp.json
      final filename = savedFile.uri.pathSegments.last;
      expect(filename, matches(RegExp(r'^test_custom_session_\d+\.json$')));

      // Then: File should be in the custom_training_sessions directory
      expect(savedPath, contains('custom_training_sessions'));

      // Then: File content should match the saved session
      final fileContent = await savedFile.readAsString();
      final savedJson = jsonDecode(fileContent) as Map<String, dynamic>;
      
      expect(savedJson['title'], equals('Test Custom Session'));
      expect(savedJson['ftmsMachineType'], equals('rower'));
      expect(savedJson['intervals'], hasLength(2));
      
      final interval1 = savedJson['intervals'][0] as Map<String, dynamic>;
      expect(interval1['title'], equals('Interval 1'));
      expect(interval1['duration'], equals(300));
      expect(interval1['targets']['Instantaneous Power'], equals(150));
      
      final interval2 = savedJson['intervals'][1] as Map<String, dynamic>;
      expect(interval2['title'], equals('Interval 2'));
      expect(interval2['duration'], equals(60));
      expect(interval2['targets']['Instantaneous Power'], equals(100));
    });

    test('saves session and can be loaded back', () async {
      // Given: Mock HTTP for GitHub cache validation (will be called when loading)
      when(testMockClient.get(
        Uri.parse('https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions'),
        headers: null,
      )).thenAnswer((_) async => http.Response(
        jsonEncode([]),
        200,
        headers: {'last-modified': 'Wed, 22 Nov 2023 12:00:00 GMT'},
      ));

      // Given: A new training session
      final originalSession = TrainingSessionDefinition(
        title: 'Round Trip Test',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(
            title: 'Main Workout',
            duration: 600,
            targets: {
              'Instantaneous Power': 200,
              'Instantaneous Cadence': 90,
              'Heart Rate': 160,
            },
          ),
        ],
        isCustom: true,
      );

      // When: Saving the session
      await testService.saveSession(originalSession);

      // Then: Loading sessions should include the newly saved session
      final loadedSessions = await testService.loadTrainingSessions(DeviceType.indoorBike);
      
      // Find the saved session in the loaded list
      final savedSession = loadedSessions.firstWhere(
        (s) => s.title == 'Round Trip Test' && s.isCustom,
      );
      
      expect(savedSession.title, equals(originalSession.title));
      expect(savedSession.ftmsMachineType, equals(originalSession.ftmsMachineType));
      expect(savedSession.intervals.length, equals(originalSession.intervals.length));
      
      final loadedInterval = savedSession.intervals[0] as UnitTrainingInterval;
      expect(loadedInterval.duration, equals(600));
      expect(loadedInterval.targets?['Instantaneous Power'], equals(200));
      expect(loadedInterval.targets?['Instantaneous Cadence'], equals(90));
      expect(loadedInterval.targets?['Heart Rate'], equals(160));
      expect(savedSession.isCustom, isTrue);
    });

    test('generates safe filenames from session titles with special characters', () async {
      // Given: A session with special characters in the title
      final sessionWithSpecialChars = TrainingSessionDefinition(
        title: 'Test/Session: With "Special" <Characters>',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(
            title: 'Test Interval',
            duration: 120,
            targets: {'Instantaneous Power': 100},
          ),
        ],
        isCustom: true,
      );

      // When: Saving the session
      final savedPath = await testService.saveSession(sessionWithSpecialChars);

      // Then: Filename should have special characters replaced with underscores
      final filename = File(savedPath).uri.pathSegments.last;
      expect(filename, matches(RegExp(r'^test_session__with__special___characters__\d+\.json$')));
      
      // Then: File should exist and be readable
      final savedFile = File(savedPath);
      expect(savedFile.existsSync(), isTrue);
      
      final fileContent = await savedFile.readAsString();
      final savedJson = jsonDecode(fileContent) as Map<String, dynamic>;
      expect(savedJson['title'], equals('Test/Session: With "Special" <Characters>'));
    });
  });

  group('deleteSession', () {
    late TrainingSessionStorageService testService;
    late Directory testTempDir;
    late MockClient testMockClient;

    setUp(() async {
      testTempDir = await Directory.systemTemp.createTemp('delete_session_test_');
      testMockClient = MockClient();
      testService = TrainingSessionStorageService(
        client: testMockClient,
        directoryProvider: _TestDirectoryProvider(testTempDir),
      );
    });

    tearDown(() async {
      await testTempDir.delete(recursive: true);
    });

    test('deletes an existing custom session', () async {
      // Create and save a session
      final session = TrainingSessionDefinition(
        title: 'Session to Delete',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(
            title: 'Test',
            duration: 300,
            targets: {'Instantaneous Power': 150},
          ),
        ],
        isCustom: true,
      );

      final filePath = await testService.saveSession(session);
      final file = File(filePath);

      // Verify file exists before deletion
      expect(await file.exists(), true);

      // Delete the session
      final result = await testService.deleteSession(
        'Session to Delete',
        'rower',
      );

      // Verify deletion was successful
      expect(result, true);

      // Verify file no longer exists
      expect(await file.exists(), false);
    });

    test('returns false when trying to delete non-existent session', () async {
      // Try to delete a session that doesn't exist
      final result = await testService.deleteSession(
        'Non-existent Session',
        'indoorBike',
      );

      expect(result, false);
    });

    test('returns false when custom sessions directory does not exist', () async {
      // Don't create any sessions, so directory won't exist
      final result = await testService.deleteSession(
        'Any Session',
        'rower',
      );

      expect(result, false);
    });

    test('deletes only the matching session when multiple sessions exist', () async {
      // Create multiple sessions
      final session1 = TrainingSessionDefinition(
        title: 'First Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(
            title: 'Interval',
            duration: 300,
            targets: {'Instantaneous Power': 100},
          ),
        ],
        isCustom: true,
      );

      final session2 = TrainingSessionDefinition(
        title: 'Second Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(
            title: 'Interval',
            duration: 300,
            targets: {'Instantaneous Power': 100},
          ),
        ],
        isCustom: true,
      );

      final session3 = TrainingSessionDefinition(
        title: 'Third Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(
            title: 'Interval',
            duration: 300,
            targets: {'Instantaneous Power': 100},
          ),
        ],
        isCustom: true,
      );

      final filePath1 = await testService.saveSession(session1);
      final filePath2 = await testService.saveSession(session2);
      final filePath3 = await testService.saveSession(session3);

      // Delete the second session
      final result = await testService.deleteSession(
        'Second Session',
        'rower',
      );

      expect(result, true);

      // Verify only session2 was deleted
      expect(await File(filePath1).exists(), true);
      expect(await File(filePath2).exists(), false);
      expect(await File(filePath3).exists(), true);
    });

    test('matches session by both title and machine type', () async {
      // Create sessions with same title but different machine types
      final rowerSession = TrainingSessionDefinition(
        title: 'Same Title',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          UnitTrainingInterval(
            title: 'Interval',
            duration: 300,
            targets: {'Instantaneous Power': 100},
          ),
        ],
        isCustom: true,
      );

      final bikeSession = TrainingSessionDefinition(
        title: 'Same Title',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(
            title: 'Interval',
            duration: 300,
            targets: {'Instantaneous Power': 100},
          ),
        ],
        isCustom: true,
      );

      final rowerPath = await testService.saveSession(rowerSession);
      final bikePath = await testService.saveSession(bikeSession);

      // Delete only the rower session
      final result = await testService.deleteSession(
        'Same Title',
        'rower',
      );

      expect(result, true);

      // Verify only rower session was deleted
      expect(await File(rowerPath).exists(), false);
      expect(await File(bikePath).exists(), true);
    });
  });
}

/// Custom DirectoryProvider for testing that uses a temporary directory
class _TestDirectoryProvider implements DirectoryProvider {
  final Directory tempDir;

  _TestDirectoryProvider(this.tempDir);

  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    return tempDir;
  }
}
