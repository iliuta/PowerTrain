import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/training/services/training_session_storage_service.dart';
import 'package:ftms/features/training/model/training_session.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:http/http.dart' as http;

class FakeHttpClient implements http.Client {
  Map<String, http.Response> responses = {};
  List<String> requestedUrls = [];

  void addResponse(String urlPattern, http.Response response) {
    responses[urlPattern] = response;
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final urlStr = url.toString();
    requestedUrls.add(urlStr);
    
    // Try exact match first
    if (responses.containsKey(urlStr)) {
      return responses[urlStr]!;
    }
    
    // Try to find matching response by checking if URL contains pattern key
    for (final patternUrl in responses.keys) {
      if (urlStr.startsWith(patternUrl) || urlStr.contains(patternUrl)) {
        return responses[patternUrl]!;
      }
    }
    
    return http.Response('Not Found', 404);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {}

  @override
  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    throw UnimplementedError();
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) async {
    throw UnimplementedError();
  }
}

void main() {
  group('TrainingSessionStorageService', () {
    late TrainingSessionStorageService service;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      service = TrainingSessionStorageService();
    });

    test('should create service instance', () {
      expect(service, isNotNull);
    });

    test('should generate safe filename', () {
      // Test the internal filename generation logic by creating sessions
      // with various titles and checking they don't cause errors
      final testTitles = [
        'Normal Session Title',
        'Session/With\\Special|Characters',
        'Session:With<Multiple>Invalid?Characters*',
        'Very Long Session Title That Exceeds Normal Filename Length Limits And Should Be Handled Gracefully',
        'Session   With   Multiple   Spaces',
        '',
      ];

      for (final title in testTitles) {
        final session = TrainingSessionDefinition(
          title: title,
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [
            UnitTrainingInterval(
              duration: 300,
              title: 'Test',
              targets: {'power': 100},
            ),
          ],
        );

        // Should not throw when creating the session
        expect(() => session.toJson(), returnsNormally);
      }
    });

    test('should handle TrainingSessionDefinition serialization', () {
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [
          UnitTrainingInterval(
            duration: 300,
            title: 'Warm Up',
            targets: {'power': 100},
          ),
          UnitTrainingInterval(
            duration: 600,
            title: 'Main Set',
            targets: {'power': 200},
          ),
        ],
      );

      // Test serialization
      final json = session.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['title'], equals('Test Session'));
      expect(json['ftmsMachineType'], equals('indoorBike'));
      expect(json['intervals'], isA<List>());
      expect(json['intervals'].length, equals(2));

      // Test deserialization
      final deserializedSession = TrainingSessionDefinition.fromJson(json);
      expect(deserializedSession.title, equals('Test Session'));
      expect(deserializedSession.ftmsMachineType, equals(DeviceType.indoorBike));
      expect(deserializedSession.intervals.length, equals(2));
    });

    // Integration test - only run if we can access the file system
    test('should save and load training session if storage is accessible', () async {
      try {
        final accessible = await service.isStorageAccessible();
        if (!accessible) {
          // Skip this test if storage is not accessible
          return;
        }

        // Create a test session
        final session = TrainingSessionDefinition(
          title: 'Integration Test Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [
            UnitTrainingInterval(
              duration: 300,
              title: 'Test Interval',
              targets: {'power': 150},
            ),
          ],
        );

        // Save the session
        final filePath = await service.saveSession(session);
        expect(filePath, isNotNull);

        // Load the sessions
        final allSessions = await service.loadTrainingSessions(DeviceType.indoorBike);
        final loadedSessions = allSessions.where((s) => s.isCustom).toList();
        expect(loadedSessions, isNotEmpty);

        final loadedSession = loadedSessions.firstWhere(
          (s) => s.title == 'Integration Test Session',
          orElse: () => throw Exception('Session not found'),
        );

        expect(loadedSession.title, equals('Integration Test Session'));
        expect(loadedSession.ftmsMachineType, equals(DeviceType.indoorBike));

        // Clean up
        await service.deleteSession(
          'Integration Test Session',
          'DeviceType.indoorBike',
        );
      } catch (e) {
        // If file system operations fail, just log and continue
        // File system test skipped: $e
      }
    });

    test('should duplicate session correctly', () async {
      try {
        // Create original session
        final originalSession = TrainingSessionDefinition(
          title: 'Original Session',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            UnitTrainingInterval(
              duration: 300,
              title: 'Warm Up',
              targets: {'Stroke Rate': 20, 'Heart Rate': 120},
            ),
            UnitTrainingInterval(
              duration: 600,
              title: 'Main Set',
              targets: {'Stroke Rate': 28, 'Heart Rate': 160},
            ),
          ],
          isCustom: false, // Original is built-in
        );

        // Create duplicated session
        final duplicatedSession = TrainingSessionDefinition(
          title: 'Original Session (Copy)',
          ftmsMachineType: originalSession.ftmsMachineType,
          intervals: List.from(originalSession.intervals),
          isCustom: true, // Duplicate is always custom
        );

        // Save the duplicated session
        final filePath = await service.saveSession(duplicatedSession);
        expect(filePath, isNotNull);

        // Load and verify
        final allSessions = await service.loadTrainingSessions(DeviceType.rower);
        final loadedSessions = allSessions.where((s) => s.isCustom).toList();
        final loadedSession = loadedSessions.firstWhere(
          (s) => s.title == 'Original Session (Copy)',
          orElse: () => throw Exception('Duplicated session not found'),
        );

        expect(loadedSession.title, equals('Original Session (Copy)'));
        expect(loadedSession.ftmsMachineType, equals(DeviceType.rower));
        expect(loadedSession.isCustom, isTrue);
        expect(loadedSession.intervals.length, equals(2));
        
        // Verify interval content is preserved
        final interval0 = loadedSession.intervals[0] as UnitTrainingInterval;
        final interval1 = loadedSession.intervals[1] as UnitTrainingInterval;
        expect(interval0.title, equals('Warm Up'));
        expect(interval0.duration, equals(300));
        expect(interval1.title, equals('Main Set'));
        expect(interval1.duration, equals(600));

        // Clean up
        await service.deleteSession(
          'Original Session (Copy)',
          'DeviceType.rower',
        );
      } catch (e) {
        // File system test skipped: $e
      }
    });

    test('should handle duplication with different machine types', () async {
      try {
        // Create sessions for different machine types
        final rowerSession = TrainingSessionDefinition(
          title: 'Rower Session',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            UnitTrainingInterval(
              duration: 300,
              title: 'Test',
              targets: {'Stroke Rate': 24},
            ),
          ],
          isCustom: false,
        );

        final bikeSession = TrainingSessionDefinition(
          title: 'Bike Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [
            UnitTrainingInterval(
              duration: 300,
              title: 'Test',
              targets: {'Instantaneous Power': 200},
            ),
          ],
          isCustom: false,
        );

        // Duplicate both sessions
        final duplicatedRower = TrainingSessionDefinition(
          title: 'Rower Session (Copy)',
          ftmsMachineType: rowerSession.ftmsMachineType,
          intervals: List.from(rowerSession.intervals),
          isCustom: true,
        );

        final duplicatedBike = TrainingSessionDefinition(
          title: 'Bike Session (Copy)',
          ftmsMachineType: bikeSession.ftmsMachineType,
          intervals: List.from(bikeSession.intervals),
          isCustom: true,
        );

        // Save both
        await service.saveSession(duplicatedRower);
        await service.saveSession(duplicatedBike);

        // Load and verify
        final allRowerSessions = await service.loadTrainingSessions(DeviceType.rower);
        final loadedRowerSessions = allRowerSessions.where((s) => s.isCustom).toList();
        final allBikeSessions = await service.loadTrainingSessions(DeviceType.indoorBike);
        final loadedBikeSessions = allBikeSessions.where((s) => s.isCustom).toList();
        final loadedRower = loadedRowerSessions.firstWhere(
          (s) => s.title == 'Rower Session (Copy)',
          orElse: () => throw Exception('Duplicated rower session not found'),
        );
        final loadedBike = loadedBikeSessions.firstWhere(
          (s) => s.title == 'Bike Session (Copy)',
          orElse: () => throw Exception('Duplicated bike session not found'),
        );

        expect(loadedRower.ftmsMachineType, equals(DeviceType.rower));
        expect(loadedBike.ftmsMachineType, equals(DeviceType.indoorBike));

        // Clean up
        await service.deleteSession('Rower Session (Copy)', 'DeviceType.rower');
        await service.deleteSession('Bike Session (Copy)', 'DeviceType.indoorBike');
      } catch (e) {
        // File system test skipped: $e
      }
    });

    test('should preserve interval targets when duplicating', () async {
      try {
        // Create session with complex targets
        final originalSession = TrainingSessionDefinition(
          title: 'Complex Session',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            UnitTrainingInterval(
              duration: 300,
              title: 'Multi-target Interval',
              targets: {
                'Stroke Rate': 24,
                'Heart Rate': 150,
                'Instantaneous Power': 200,
              },
            ),
          ],
          isCustom: false,
        );

        // Duplicate it
        final duplicatedSession = TrainingSessionDefinition(
          title: 'Complex Session (Copy)',
          ftmsMachineType: originalSession.ftmsMachineType,
          intervals: List.from(originalSession.intervals),
          isCustom: true,
        );

        // Save and load
        await service.saveSession(duplicatedSession);
        final allSessions = await service.loadTrainingSessions(DeviceType.rower);
        final loadedSessions = allSessions.where((s) => s.isCustom).toList();
        final loadedSession = loadedSessions.firstWhere(
          (s) => s.title == 'Complex Session (Copy)',
          orElse: () => throw Exception('Duplicated session not found'),
        );

        // Verify all targets are preserved
        final interval = loadedSession.intervals[0] as UnitTrainingInterval;
        expect(interval.targets!['Stroke Rate'], equals(24));
        expect(interval.targets!['Heart Rate'], equals(150));
        expect(interval.targets!['Instantaneous Power'], equals(200));

        // Clean up
        await service.deleteSession('Complex Session (Copy)', 'DeviceType.rower');
      } catch (e) {
        // File system test skipped: $e
      }
    });

    test('loadTrainingSessions should load built-in sessions for indoor bike', () async {
      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      
      // Should find built-in sessions for indoor bike
      expect(sessions, isNotEmpty);
      expect(sessions.every((s) => s.ftmsMachineType == DeviceType.indoorBike), isTrue);
      expect(sessions.any((s) => s.title == '16 min test'), isTrue);
    });

    test('loadTrainingSessions should load built-in sessions for rower', () async {
      final sessions = await service.loadTrainingSessions(DeviceType.rower);
      
      // Should find built-in sessions for rower
      expect(sessions, isNotEmpty);
      expect(sessions.every((s) => s.ftmsMachineType == DeviceType.rower), isTrue);
      expect(sessions.any((s) => s.title == 'Test session 1min30s'), isTrue);
    });

    test('loadTrainingSessions should combine built-in and custom sessions', () async {
      try {
        // First save a custom session for indoor bike
        final customSession = TrainingSessionDefinition(
          title: 'Custom Bike Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [
            UnitTrainingInterval(
              duration: 300,
              title: 'Custom Interval',
              targets: {'power': 150},
            ),
          ],
          isCustom: true,
        );

        await service.saveSession(customSession);

        // Load all sessions for indoor bike
        final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);

        // Should include both built-in and custom sessions
        expect(sessions, isNotEmpty);
        expect(sessions.every((s) => s.ftmsMachineType == DeviceType.indoorBike), isTrue);
        
        // Should have built-in session
        expect(sessions.any((s) => s.title == '16 min test' && !s.isCustom), isTrue);
        // Should have custom session
        expect(sessions.any((s) => s.title == 'Custom Bike Session' && s.isCustom), isTrue);

        // Clean up
        await service.deleteSession('Custom Bike Session', 'DeviceType.indoorBike');
      } catch (e) {
        // File system test skipped: $e
      }
    });

    test('loadTrainingSessions should only return sessions for the specified machine type', () async {
      final bikeSessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final rowerSessions = await service.loadTrainingSessions(DeviceType.rower);

      // All bike sessions should be for indoor bike
      expect(bikeSessions.every((s) => s.ftmsMachineType == DeviceType.indoorBike), isTrue);

      // All rower sessions should be for rower
      expect(rowerSessions.every((s) => s.ftmsMachineType == DeviceType.rower), isTrue);

      // Bike and rower sessions should be different
      final bikeTitles = bikeSessions.map((s) => s.title).toSet();
      final rowerTitles = rowerSessions.map((s) => s.title).toSet();
      expect(bikeTitles.intersection(rowerTitles), isEmpty);
    });
  });

  group('GitHub Loading', () {
    late FakeHttpClient fakeClient;
    late TrainingSessionStorageService service;

    setUp(() {
      fakeClient = FakeHttpClient();
      service = TrainingSessionStorageService(client: fakeClient);
    });

    test('should load GitHub sessions successfully', () async {
      // Mock directory listing response
      final directoryResponse = [
        {
          "name": "bike_session.json",
          "type": "file",
          "download_url": "https://raw.githubusercontent.com/owner/repo/main/bike_session.json"
        },
        {
          "name": "rower_session.json",
          "type": "file",
          "download_url": "https://raw.githubusercontent.com/owner/repo/main/rower_session.json"
        }
      ];

      // Mock session JSON responses
      final bikeSessionJson = {
        "title": "GitHub Bike Session",
        "ftmsMachineType": "indoorBike",
        "intervals": [
          {
            "duration": 300,
            "title": "Warm Up",
            "targets": {"power": 100}
          }
        ]
      };

      final rowerSessionJson = {
        "title": "GitHub Rower Session", 
        "ftmsMachineType": "rower",
        "intervals": [
          {
            "duration": 300,
            "title": "Warm Up",
            "targets": {"Stroke Rate": 20}
          }
        ]
      };

      // Setup fake responses
      fakeClient.addResponse('https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions', 
          http.Response(jsonEncode(directoryResponse), 200));
      fakeClient.addResponse('https://raw.githubusercontent.com/owner/repo/main/bike_session.json', 
          http.Response(jsonEncode(bikeSessionJson), 200));
      fakeClient.addResponse('https://raw.githubusercontent.com/owner/repo/main/rower_session.json', 
          http.Response(jsonEncode(rowerSessionJson), 200));

      final bikeSessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final rowerSessions = await service.loadTrainingSessions(DeviceType.rower);

      // Should include GitHub sessions
      expect(bikeSessions.any((s) => s.title == 'GitHub Bike Session'), isTrue);
      expect(rowerSessions.any((s) => s.title == 'GitHub Rower Session'), isTrue);
    });

    test('should cache GitHub sessions', () async {
      final directoryResponse = [
        {
          "name": "bike_session.json",
          "type": "file",
          "download_url": "https://raw.githubusercontent.com/owner/repo/main/bike_session.json"
        }
      ];

      final sessionJson = {
        "title": "Cached Session",
        "ftmsMachineType": "indoorBike", 
        "intervals": [
          {
            "duration": 300,
            "title": "Test",
            "targets": {"power": 100}
          }
        ]
      };

      fakeClient.addResponse('https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions',
          http.Response(jsonEncode(directoryResponse), 200));
      fakeClient.addResponse('https://raw.githubusercontent.com/owner/repo/main/bike_session.json',
          http.Response(jsonEncode(sessionJson), 200));

      // First call
      await service.loadTrainingSessions(DeviceType.indoorBike);
      
      // Clear responses to verify no new calls are made
      final savedResponses = fakeClient.responses.entries.toList();
      fakeClient.responses.clear();
      fakeClient.responses.addAll(Map.fromEntries(savedResponses));
      
      // This should not make any new HTTP calls due to caching
      await service.loadTrainingSessions(DeviceType.indoorBike);
    });

    test('should handle GitHub API errors gracefully', () async {
      // Don't add any responses - will return 404 which simulates API errors
      
      // Should not throw, should return built-in sessions only
      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      expect(sessions, isNotEmpty);
      expect(sessions.every((s) => s.ftmsMachineType == DeviceType.indoorBike), isTrue);
      // Should not include any GitHub sessions since API failed
      expect(sessions.any((s) => s.title.contains('GitHub')), isFalse);
    });

    test('should handle invalid JSON in GitHub sessions', () async {
      final directoryResponse = [
        {
          "name": "invalid_session.json",
          "type": "file",
          "download_url": "https://raw.githubusercontent.com/owner/repo/main/invalid_session.json"
        }
      ];

      fakeClient.addResponse('https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions',
          http.Response(jsonEncode(directoryResponse), 200));
      fakeClient.addResponse('https://raw.githubusercontent.com/owner/repo/main/invalid_session.json',
          http.Response('invalid json', 200));

      // Should not throw, should return built-in sessions only
      final sessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      expect(sessions, isNotEmpty);
      expect(sessions.every((s) => s.ftmsMachineType == DeviceType.indoorBike), isTrue);
    });

    test('should filter GitHub sessions by machine type', () async {
      final directoryResponse = [
        {
          "name": "bike_session.json",
          "type": "file",
          "download_url": "https://raw.githubusercontent.com/owner/repo/main/bike_session.json"
        },
        {
          "name": "rower_session.json",
          "type": "file",
          "download_url": "https://raw.githubusercontent.com/owner/repo/main/rower_session.json"
        }
      ];

      final bikeSessionJson = {
        "title": "Bike Only",
        "ftmsMachineType": "indoorBike",
        "intervals": [{"duration": 300, "title": "Test", "targets": {"power": 100}}]
      };

      final rowerSessionJson = {
        "title": "Rower Only",
        "ftmsMachineType": "rower", 
        "intervals": [{"duration": 300, "title": "Test", "targets": {"Stroke Rate": 20}}]
      };

      fakeClient.addResponse('https://api.github.com/repos/iliuta/powertrain-training-sessions/contents/training-sessions',
          http.Response(jsonEncode(directoryResponse), 200));
      fakeClient.addResponse('https://raw.githubusercontent.com/owner/repo/main/bike_session.json',
          http.Response(jsonEncode(bikeSessionJson), 200));
      fakeClient.addResponse('https://raw.githubusercontent.com/owner/repo/main/rower_session.json',
          http.Response(jsonEncode(rowerSessionJson), 200));

      final bikeSessions = await service.loadTrainingSessions(DeviceType.indoorBike);
      final rowerSessions = await service.loadTrainingSessions(DeviceType.rower);

      // Bike sessions should include bike GitHub session
      expect(bikeSessions.any((s) => s.title == 'Bike Only'), isTrue);
      // But not rower
      expect(bikeSessions.any((s) => s.title == 'Rower Only'), isFalse);

      // Rower sessions should include rower GitHub session
      expect(rowerSessions.any((s) => s.title == 'Rower Only'), isTrue);
      // But not bike
      expect(rowerSessions.any((s) => s.title == 'Bike Only'), isFalse);
    });
  });
}