import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ftms/core/utils/logger.dart';
import 'package:ftms/core/models/device_types.dart';
import '../model/training_session.dart';

/// Service for saving and loading user-created training sessions
class TrainingSessionStorageService {
  static TrainingSessionStorageService? _instance;

  factory TrainingSessionStorageService({http.Client? client}) {
    if (client != null) {
      return TrainingSessionStorageService._internal(client);
    }
    _instance ??= TrainingSessionStorageService._internal(http.Client());
    return _instance!;
  }

  TrainingSessionStorageService._internal(this._client);

  late final http.Client _client;

  static const String _customSessionsDir = 'custom_training_sessions';

  // Cache for GitHub sessions - persists for app session
  final Map<DeviceType, List<TrainingSessionDefinition>> _githubSessionsCache = {};

  /// Get the directory where custom training sessions are stored
  Future<Directory> _getCustomSessionsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final customSessionsDir = Directory('${documentsDir.path}/$_customSessionsDir');
    
    if (!await customSessionsDir.exists()) {
      await customSessionsDir.create(recursive: true);
    }
    
    return customSessionsDir;
  }

  /// Save a training session to persistent storage
  Future<String> saveSession(TrainingSessionDefinition session) async {
    try {
      final directory = await _getCustomSessionsDirectory();
      
      // Generate a safe filename from the session title
      final safeTitle = _generateSafeFilename(session.title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${safeTitle}_$timestamp.json';
      final filePath = '${directory.path}/$filename';
      
      // Convert session to JSON
      final sessionJson = session.toJson();
      final jsonString = jsonEncode(sessionJson);
      
      // Write to file
      final file = File(filePath);
      await file.writeAsString(jsonString, encoding: utf8);
      
      logger.i('Training session saved successfully: $filePath');
      return filePath;
    } catch (e) {
      logger.e('Failed to save training session: $e');
      throw Exception('Failed to save training session: $e');
    }
  }

  /// Load all custom training sessions for a specific machine type
  Future<List<TrainingSessionDefinition>> _loadCustomSessions(DeviceType machineType) async {
    try {
      final directory = await _getCustomSessionsDirectory();
      final sessions = <TrainingSessionDefinition>[];
      
      if (!await directory.exists()) {
        return sessions;
      }
      
      final files = directory.listSync()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>();
      
      for (final file in files) {
        try {
          final content = await file.readAsString(encoding: utf8);
          final jsonData = jsonDecode(content) as Map<String, dynamic>;
          final session = TrainingSessionDefinition.fromJson(jsonData, isCustom: true);
          if (session.ftmsMachineType == machineType) {
            sessions.add(session);
          }
        } catch (e) {
          logger.w('Failed to load session from ${file.path}: $e');
          // Continue loading other sessions even if one fails
        }
      }
      
      logger.i('Loaded ${sessions.length} custom training sessions for $machineType');
      return sessions;
    } catch (e) {
      logger.e('Failed to load custom training sessions: $e');
      return [];
    }
  }

  /// Delete a custom training session by searching for sessions with matching title and machine type
  Future<bool> deleteSession(String title, String machineType) async {
    try {
      final directory = await _getCustomSessionsDirectory();
      
      if (!await directory.exists()) {
        return false;
      }
      
      final files = directory.listSync()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>();
      
      for (final file in files) {
        try {
          final content = await file.readAsString(encoding: utf8);
          final jsonData = jsonDecode(content) as Map<String, dynamic>;
          
          if (jsonData['title'] == title && jsonData['ftmsMachineType'] == machineType) {
            await file.delete();
            logger.i('Deleted training session: ${file.path}');
            return true;
          }
        } catch (e) {
          logger.w('Failed to check session in ${file.path}: $e');
        }
      }
      
      logger.w('No matching session found for deletion: $title ($machineType)');
      return false;
    } catch (e) {
      logger.e('Failed to delete training session: $e');
      return false;
    }
  }

  /// Generate a safe filename from a session title
  String _generateSafeFilename(String title) {
    // Replace invalid filename characters with underscores
    final safeTitle = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    
    // Limit length to avoid filesystem issues
    return safeTitle.length > 50 ? safeTitle.substring(0, 50) : safeTitle;
  }

  /// Get the total number of custom training sessions
  Future<int> getCustomSessionCount() async {
    try {
      final directory = await _getCustomSessionsDirectory();
      
      if (!await directory.exists()) {
        return 0;
      }
      
      final files = directory.listSync()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .toList();
      
      return files.length;
    } catch (e) {
      logger.e('Failed to get custom session count: $e');
      return 0;
    }
  }

  /// Check if the storage directory is accessible
  Future<bool> isStorageAccessible() async {
    try {
      final directory = await _getCustomSessionsDirectory();
      return await directory.exists();
    } catch (e) {
      logger.e('Storage accessibility check failed: $e');
      return false;
    }
  }

  /// Load built-in training sessions from assets for a specific machine type
  Future<List<TrainingSessionDefinition>> _loadBuiltInSessions(DeviceType machineType) async {
    final List<TrainingSessionDefinition> sessions = [];

    // Load built-in sessions from assets
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final sessionFiles = manifestMap.keys
        .where((String key) => key.startsWith('lib/training-sessions/') && key.endsWith('.json'))
        .toList();
    logger.i('[loadBuiltInSessions] Found built-in files:');
    for (final f in sessionFiles) {
      logger.i('  - $f');
    }

    // Load built-in sessions
    for (final file in sessionFiles) {
      try {
        final content = await rootBundle.loadString(file);
        final jsonData = json.decode(content);
        final session = TrainingSessionDefinition.fromJson(jsonData, isCustom: false);
        logger.i('[loadBuiltInSessions] Read built-in session: title=${session.title}, ftmsMachineType=${session.ftmsMachineType}');
        if (session.ftmsMachineType == machineType) {
          logger.i('[loadBuiltInSessions]   -> MATCH');
          sessions.add(session);
        } else {
          logger.i('[loadBuiltInSessions]   -> SKIP');
        }
      } catch (e) {
        logger.e('[loadBuiltInSessions] Error reading $file: $e');
      }
    }

    return sessions;
  }

  /// Load built-in training sessions from GitHub repository for a specific machine type
  /// Sessions are cached in memory for the duration of the app session
  Future<List<TrainingSessionDefinition>> _loadBuiltInSessionsFromGithub(DeviceType machineType) async {
    // Check cache first
    if (_githubSessionsCache.containsKey(machineType)) {
      logger.i('[loadBuiltInSessionsFromGithub] Returning cached sessions for $machineType');
      return _githubSessionsCache[machineType]!;
    }

    final List<TrainingSessionDefinition> sessions = [];

    try {
      const String owner = 'iliuta'; // Replace with actual GitHub username/organization
      const String repo = 'powertrain-training-sessions'; // Replace with actual repository name
      const String path = 'training-sessions'; // Directory containing session files

      // GitHub API URL to list files in directory
      final apiUrl = 'https://api.github.com/repos/$owner/$repo/contents/$path';

      logger.i('[loadBuiltInSessionsFromGithub] Fetching session list from GitHub: $apiUrl');

      final response = await _client.get(Uri.parse(apiUrl));

      if (response.statusCode != 200) {
        logger.w('[loadBuiltInSessionsFromGithub] Failed to fetch from GitHub API: ${response.statusCode}');
        return sessions; // Return empty list on failure
      }

      final List<dynamic> files = json.decode(response.body);

      // Filter for JSON files only
      final jsonFiles = files.where((file) =>
        file['type'] == 'file' &&
        file['name'].toString().endsWith('.json')
      ).toList();

      logger.i('[loadBuiltInSessionsFromGithub] Found ${jsonFiles.length} JSON files on GitHub');

      // Load each session file
      for (final file in jsonFiles) {
        try {
          final downloadUrl = file['download_url'];
          logger.i('[loadBuiltInSessionsFromGithub] Loading session: ${file['name']}');

          final sessionResponse = await _client.get(Uri.parse(downloadUrl));

          if (sessionResponse.statusCode == 200) {
            final jsonData = json.decode(sessionResponse.body);
            final session = TrainingSessionDefinition.fromJson(jsonData, isCustom: false);

            if (session.ftmsMachineType == machineType) {
              logger.i('[loadBuiltInSessionsFromGithub] Added GitHub session: ${session.title}');
              sessions.add(session);
            }
          } else {
            logger.w('[loadBuiltInSessionsFromGithub] Failed to load ${file['name']}: ${sessionResponse.statusCode}');
          }
        } catch (e) {
          logger.w('[loadBuiltInSessionsFromGithub] Error loading ${file['name']}: $e');
        }
      }

      // Cache the results
      _githubSessionsCache[machineType] = sessions;
      logger.i('[loadBuiltInSessionsFromGithub] Cached ${sessions.length} sessions for $machineType');

    } catch (e) {
      logger.e('[loadBuiltInSessionsFromGithub] Error loading GitHub sessions: $e');
      // Return empty list on error, don't throw
    }

    return sessions;
  }

  /// Load all training sessions (built-in and custom) for a specific machine type
  Future<List<TrainingSessionDefinition>> loadTrainingSessions(DeviceType machineType) async {
    logger.i('[loadTrainingSessions] machineType: $machineType');
    final List<TrainingSessionDefinition> sessions = [];

    // Load built-in sessions
    try {
      final builtInSessions = await _loadBuiltInSessions(machineType);
      sessions.addAll(builtInSessions);
    } catch (e) {
      logger.e('[loadTrainingSessions] Error loading built-in sessions: $e');
    }

    // Load GitHub sessions
    try {
      final githubSessions = await _loadBuiltInSessionsFromGithub(machineType);
      sessions.addAll(githubSessions);
    } catch (e) {
      logger.e('[loadTrainingSessions] Error loading GitHub sessions: $e');
    }

    // Load custom sessions
    try {
      final customSessions = await _loadCustomSessions(machineType);
      logger.i('[loadTrainingSessions] Found ${customSessions.length} custom sessions');
      sessions.addAll(customSessions);
    } catch (e) {
      logger.e('[loadTrainingSessions] Error loading custom sessions: $e');
    }

    logger.i('[loadTrainingSessions] Returning ${sessions.length} total sessions');
    return sessions;
  }
}