import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:ftms/core/utils/logger.dart';
import 'package:ftms/core/models/device_types.dart';
import '../model/training_session.dart';

/// Interface for directory operations - allows injection for testing
abstract class DirectoryProvider {
  Future<Directory> getApplicationDocumentsDirectory();
}

/// Default implementation using path_provider
class PathProviderDirectoryProvider implements DirectoryProvider {
  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    return await path_provider.getApplicationDocumentsDirectory();
  }
}

/// Interface for asset bundle operations - allows injection for testing
abstract class AssetBundleProvider {
  Future<String> loadString(String key);
}

/// Default implementation using rootBundle
class RootAssetBundleProvider implements AssetBundleProvider {
  @override
  Future<String> loadString(String key) async {
    return await rootBundle.loadString(key);
  }
}

/// Service for saving and loading user-created training sessions
class TrainingSessionStorageService {
  static TrainingSessionStorageService? _instance;

  factory TrainingSessionStorageService({http.Client? client, DirectoryProvider? directoryProvider, AssetBundleProvider? assetBundleProvider}) {
    if (client != null || directoryProvider != null || assetBundleProvider != null) {
      return TrainingSessionStorageService._internal(
        client ?? http.Client(),
        directoryProvider ?? PathProviderDirectoryProvider(),
        assetBundleProvider ?? RootAssetBundleProvider(),
      );
    }
    _instance ??= TrainingSessionStorageService._internal(
      http.Client(),
      PathProviderDirectoryProvider(),
      RootAssetBundleProvider(),
    );
    // Load GitHub cache from disk on first initialization
    _instance!._loadGitHubCacheFromDisk().catchError((e) {
      logger.w('[TrainingSessionStorageService] Failed to load GitHub cache from disk: $e');
    });
    return _instance!;
  }

  TrainingSessionStorageService._internal(this._client, this._directoryProvider, this._assetBundleProvider);

  late final http.Client _client;
  late final DirectoryProvider _directoryProvider;
  late final AssetBundleProvider _assetBundleProvider;

  static const String _customSessionsDir = 'custom_training_sessions';
  static const String _githubCacheDir = 'github_sessions_cache';
  static const String _cacheMetadataFile = 'cache_metadata.json';

  // Cache for GitHub sessions - persists for app session
  final Map<DeviceType, List<TrainingSessionDefinition>> _githubSessionsCache = {};

  /// Public getter for testing cache contents
  Map<DeviceType, List<TrainingSessionDefinition>> get githubSessionsCache => _githubSessionsCache;

  /// Get the directory where GitHub sessions cache is stored
  Future<Directory> _getGitHubCacheDirectory() async {
    final documentsDir = await _directoryProvider.getApplicationDocumentsDirectory();
    final cacheDir = Directory('${documentsDir.path}/$_githubCacheDir');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// Get cache metadata file path
  Future<File> _getCacheMetadataFile() async {
    final cacheDir = await _getGitHubCacheDirectory();
    return File('${cacheDir.path}/$_cacheMetadataFile');
  }

  /// Load GitHub sessions cache from persistent storage
  Future<void> _loadGitHubCacheFromDisk() async {
    try {
      final cacheDir = await _getGitHubCacheDirectory();
      if (!await cacheDir.exists()) {
        return;
      }

      final metadataFile = await _getCacheMetadataFile();
      if (!await metadataFile.exists()) {
        return;
      }

      final metadataContent = await metadataFile.readAsString(encoding: utf8);
      final metadata = jsonDecode(metadataContent) as Map<String, dynamic>;

      // Load each cached machine type
      for (final entry in metadata.entries) {
        final machineTypeStr = entry.key;
        if (machineTypeStr == 'lastUpdated' || machineTypeStr == 'lastModified') continue;

        final deviceType = _parseDeviceType(machineTypeStr);
        if (deviceType == null) continue;

        final cacheFile = File('${cacheDir.path}/$machineTypeStr.json');
        if (await cacheFile.exists()) {
          try {
            final content = await cacheFile.readAsString(encoding: utf8);
            final sessionsData = jsonDecode(content) as List<dynamic>;
            final sessions = sessionsData
                .map((item) => TrainingSessionDefinition.fromJson(item as Map<String, dynamic>, isCustom: false))
                .toList();
            _githubSessionsCache[deviceType] = sessions;
            logger.i('[loadGitHubCacheFromDisk] Loaded ${sessions.length} cached sessions for $machineTypeStr');
          } catch (e) {
            logger.w('[loadGitHubCacheFromDisk] Failed to load cache for $machineTypeStr: $e');
          }
        }
      }
    } catch (e) {
      logger.e('[loadGitHubCacheFromDisk] Error loading GitHub cache: $e');
    }
  }

  /// Save GitHub sessions cache to persistent storage with HTTP header metadata
  Future<void> _saveGitHubCacheToDisk(String? lastModifiedHeader, List<TrainingSessionDefinition> sessions) async {
    try {
      final cacheDir = await _getGitHubCacheDirectory();
      final metadata = <String, dynamic>{};

      // Save sessions
      final cacheFile = File('${cacheDir.path}/github-cache.json');
      final sessionsJson = sessions.map((s) => s.toJson()).toList();
      await cacheFile.writeAsString(jsonEncode(sessionsJson), encoding: utf8);

      logger.i('[saveGitHubCacheToDisk] Saved ${sessions.length} sessions');

      // Save metadata with timestamps
      final metadataFile = await _getCacheMetadataFile();
      metadata['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;
      if (lastModifiedHeader != null) {
        metadata['lastModified'] = lastModifiedHeader;
        logger.i('[saveGitHubCacheToDisk] Stored Last-Modified header: $lastModifiedHeader');
      }
      await metadataFile.writeAsString(jsonEncode(metadata), encoding: utf8);
    } catch (e) {
      logger.e('[saveGitHubCacheToDisk] Error saving GitHub cache: $e');
    }
  }

  /// Parse DeviceType from string representation
  DeviceType? _parseDeviceType(String typeStr) {
    for (final type in DeviceType.values) {
      if (type.toString() == typeStr) {
        return type;
      }
    }
    return null;
  }

  /// Get the cached Last-Modified header from metadata file
  Future<String?> _getCachedLastModified() async {
    try {
      final metadataFile = await _getCacheMetadataFile();
      if (!await metadataFile.exists()) {
        return null;
      }

      final metadataContent = await metadataFile.readAsString(encoding: utf8);
      final metadata = jsonDecode(metadataContent) as Map<String, dynamic>;
      return metadata['lastModified'] as String?;
    } catch (e) {
      logger.w('[_getCachedLastModified] Failed to read cached Last-Modified: $e');
      return null;
    }
  }

  /// Fetch GitHub repository Last-Modified header
  Future<String?> _fetchGitHubLastModified() async {
    try {
      const String owner = 'iliuta';
      const String repo = 'powertrain-training-sessions';
      const String path = 'training-sessions';
      final apiUrl = 'https://api.github.com/repos/$owner/$repo/contents/$path';

      final response = await _client.get(Uri.parse(apiUrl));
      if (response.statusCode != 200) {
        logger.w('[_fetchGitHubLastModified] GitHub API returned ${response.statusCode}');
        return null;
      }

      return response.headers['last-modified'];
    } catch (e) {
      logger.e('[_fetchGitHubLastModified] Error fetching from GitHub: $e');
      return null;
    }
  }

  /// Download and parse session files from GitHub
  Future<List<TrainingSessionDefinition>> _downloadSessionsFromGithub() async {
    const String owner = 'iliuta';
    const String repo = 'powertrain-training-sessions';
    const String path = 'training-sessions';
    final apiUrl = 'https://api.github.com/repos/$owner/$repo/contents/$path';

    final response = await _client.get(Uri.parse(apiUrl));
    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}');
    }

    final List<dynamic> files = json.decode(response.body);
    final jsonFiles = files.where((file) =>
      file['type'] == 'file' && file['name'].toString().endsWith('.json')
    ).toList();

    logger.i('[_downloadSessionsFromGithub] Found ${jsonFiles.length} JSON files on GitHub');

    final sessions = <TrainingSessionDefinition>[];
    for (final file in jsonFiles) {
      try {
        final downloadUrl = file['download_url'];
        logger.i('[_downloadSessionsFromGithub] Loading session: ${file['name']}');

        final sessionResponse = await _client.get(Uri.parse(downloadUrl));
        if (sessionResponse.statusCode == 200) {
          final jsonData = json.decode(sessionResponse.body);
          final session = TrainingSessionDefinition.fromJson(jsonData, isCustom: false);

          logger.i('[_downloadSessionsFromGithub] Added GitHub session: ${session.title}');
          sessions.add(session);
        } else {
          logger.w('[_downloadSessionsFromGithub] Failed to load ${file['name']}: ${sessionResponse.statusCode}');
        }
      } catch (e) {
        logger.w('[_downloadSessionsFromGithub] Error loading ${file['name']}: $e');
      }
    }

    return sessions;
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


  /// Load built-in training sessions from assets for a specific machine type
  Future<List<TrainingSessionDefinition>> _loadBuiltInSessions(DeviceType machineType) async {
    final List<TrainingSessionDefinition> sessions = [];

    // Load built-in sessions from assets
    final manifestContent = await AssetManifest.loadFromAssetBundle(rootBundle);
    final manifests = manifestContent.listAssets();

    final sessionFiles = manifests
        .where((String key) => key.startsWith('lib/training-sessions/') && key.endsWith('.json'))
        .toList();
    logger.i('[loadBuiltInSessions] Found built-in files:');
    for (final f in sessionFiles) {
      logger.i('  - $f');
    }

    // Load built-in sessions
    for (final file in sessionFiles) {
      try {
        final content = await _assetBundleProvider.loadString(file);
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
  /// Sessions are cached on disk for persistence across app restarts
  /// Falls back to cached sessions if GitHub is unreachable
  Future<List<TrainingSessionDefinition>> _loadBuiltInSessionsFromGithub(DeviceType machineType) async {
    // Check in-memory cache first
    if (_githubSessionsCache.containsKey(machineType)) {
      logger.i('[loadBuiltInSessionsFromGithub] Returning in-memory cached sessions for $machineType');
      return _githubSessionsCache[machineType]!;
    }

    try {
      // Check if cache is up-to-date using Last-Modified headers
      final cachedLastModified = await _getCachedLastModified();
      logger.i('[loadBuiltInSessionsFromGithub] Cached Last-Modified: $cachedLastModified');

      final githubLastModified = await _fetchGitHubLastModified();
      logger.i('[loadBuiltInSessionsFromGithub] GitHub Last-Modified: $githubLastModified');

      // If cache is up-to-date, use it
      if (cachedLastModified != null &&
          githubLastModified != null &&
          cachedLastModified == githubLastModified) {
        logger.i('[loadBuiltInSessionsFromGithub] Cache is up-to-date, using cached sessions');
        return await _loadGitHubSessionsFromDiskCache(machineType);
      }

      // Cache is stale or missing, download from GitHub
      logger.i('[loadBuiltInSessionsFromGithub] Cache is stale or missing, downloading from GitHub');
      final sessions = await _downloadSessionsFromGithub();
      await _saveGitHubCacheToDisk(githubLastModified, sessions);

      // for each machine type, save to in-memory cache
      for (final mt in DeviceType.values) {
        _githubSessionsCache[mt] = sessions.where((s) => s.ftmsMachineType == mt).toList();
      }

      return sessions;
    } catch (e) {
      logger.e('[loadBuiltInSessionsFromGithub] Error loading GitHub sessions: $e - falling back to cache');
      // Fall back to cache on any error
      return await _loadGitHubSessionsFromDiskCache(machineType);
    }
  }

  /// Load GitHub sessions from disk cache for a specific machine type
  Future<List<TrainingSessionDefinition>> _loadGitHubSessionsFromDiskCache(DeviceType machineType) async {
    try {
      final cacheDir = await _getGitHubCacheDirectory();
      final cacheFile = File('${cacheDir.path}/github-cache.json');

      if (!await cacheFile.exists()) {
        logger.i('[loadGitHubSessionsFromCache] No cache found');
        return [];
      }

      final content = await cacheFile.readAsString(encoding: utf8);
      final sessionsData = jsonDecode(content) as List<dynamic>;
      final sessions = sessionsData
          .map((item) => TrainingSessionDefinition.fromJson(item as Map<String, dynamic>, isCustom: false))
          .where((session) => session.ftmsMachineType == machineType)
          .toList();
      _githubSessionsCache[machineType] = sessions;
      logger.i('[loadGitHubSessionsFromCache] Loaded ${sessions.length} cached sessions for $machineType');
      return sessions;
    } catch (e) {
      logger.w('[loadGitHubSessionsFromCache] Error loading cache for $machineType: $e');
      return [];
    }
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

  /// Get the directory where custom training sessions are stored
  Future<Directory> _getCustomSessionsDirectory() async {
    final documentsDir = await _directoryProvider.getApplicationDocumentsDirectory();
    final customSessionsDir = Directory('${documentsDir.path}/$_customSessionsDir');

    if (!await customSessionsDir.exists()) {
      await customSessionsDir.create(recursive: true);
    }

    return customSessionsDir;
  }
}