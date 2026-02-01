import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ftms/core/utils/logger.dart';
import 'package:ftms/features/settings/model/user_settings.dart';

/// Singleton service for managing UserSettings.
/// This is the only entry point for saving and retrieving UserSettings objects.
class UserSettingsService {
  static final UserSettingsService _instance = UserSettingsService._internal();
  
  static late SharedPreferences _prefs;
  UserSettings? _cachedSettings;
  
  UserSettingsService._internal();
  
  static UserSettingsService get instance => _instance;
  
  /// Initialize the service with SharedPreferences instance.
  /// Call this once during app startup for better performance.
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    logger.d('UserSettingsService initialized');
  }
  
  /// Load UserSettings from cache, SharedPreferences, or default asset.
  /// If initialize() was not called, SharedPreferences will be obtained on demand.
  Future<UserSettings> loadSettings() async {
    // Return cached settings if available
    if (_cachedSettings != null) {
      logger.d('Returning cached user settings');
      return _cachedSettings!;
    }
    
    try {
      // Ensure SharedPreferences is initialized
      _prefs = await SharedPreferences.getInstance();
      
      final jsonString = _prefs.getString(_prefsKey);
      
      if (jsonString != null) {
        logger.d('Loading user settings from SharedPreferences');
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        _cachedSettings = UserSettings.fromJson(jsonMap);
        return _cachedSettings!;
      } else {
        logger.d('No saved user settings found, loading defaults from asset');
        _cachedSettings = await _loadFromAsset();
        return _cachedSettings!;
      }
    } catch (e) {
      logger.w('Failed to load user settings from SharedPreferences, falling back to asset: $e');
      try {
        _cachedSettings = await _loadFromAsset();
        return _cachedSettings!;
      } catch (assetError) {
        logger.e('Failed to load default user settings from asset: $assetError');
        // Return sensible defaults if all else fails
        _cachedSettings = const UserSettings(
          cyclingFtp: 250,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: true,
        );
        return _cachedSettings!;
      }
    }
  }
  
  /// Save settings to SharedPreferences and update cache.
  Future<void> saveSettings(UserSettings settings) async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(settings.toJson());
      await _prefs.setString(_prefsKey, jsonString);
      _cachedSettings = settings;
      logger.d('User settings saved to SharedPreferences');
    } catch (e) {
      logger.e('Failed to save user settings: $e');
      throw Exception('Failed to save user settings: $e');
    }
  }
  
  /// Get cached settings without loading from storage.
  /// Returns null if settings have not been loaded yet.
  UserSettings? getCachedSettings() => _cachedSettings;
  
  /// Clear the cached settings.
  void clearCache() {
    _cachedSettings = null;
    logger.d('User settings cache cleared');
  }

  /// Update the soundEnabled setting.
  Future<void> setSoundEnabled(bool enabled) async {
    final currentSettings = await loadSettings();
    final updatedSettings = UserSettings(
      cyclingFtp: currentSettings.cyclingFtp,
      rowingFtp: currentSettings.rowingFtp,
      developerMode: currentSettings.developerMode,
      soundEnabled: enabled,
      metronomeSoundEnabled: currentSettings.metronomeSoundEnabled,
      demoModeEnabled: currentSettings.demoModeEnabled,
    );
    await saveSettings(updatedSettings);
    logger.d('Sound enabled setting updated to: $enabled');
  }

  /// Update the metronomeSoundEnabled setting.
  Future<void> setMetronomeSoundEnabled(bool enabled) async {
    final currentSettings = await loadSettings();
    final updatedSettings = UserSettings(
      cyclingFtp: currentSettings.cyclingFtp,
      rowingFtp: currentSettings.rowingFtp,
      developerMode: currentSettings.developerMode,
      soundEnabled: currentSettings.soundEnabled,
      metronomeSoundEnabled: enabled,
      demoModeEnabled: currentSettings.demoModeEnabled,
    );
    await saveSettings(updatedSettings);
    logger.d('Metronome sound enabled setting updated to: $enabled');
  }

  /// Update the demoModeEnabled setting.
  Future<void> setDemoModeEnabled(bool enabled) async {
    final currentSettings = await loadSettings();
    final updatedSettings = UserSettings(
      cyclingFtp: currentSettings.cyclingFtp,
      rowingFtp: currentSettings.rowingFtp,
      developerMode: currentSettings.developerMode,
      soundEnabled: currentSettings.soundEnabled,
      metronomeSoundEnabled: currentSettings.metronomeSoundEnabled,
      demoModeEnabled: enabled,
    );
    await saveSettings(updatedSettings);
    logger.d('Demo mode enabled setting updated to: $enabled');
  }
  
  static Future<UserSettings> _loadFromAsset() async {
    logger.d('Loading default user settings from asset: lib/config/default_user_settings.json');
    final jsonString = await rootBundle.loadString('lib/config/default_user_settings.json');
    logger.d('Loaded user settings JSON: $jsonString');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    logger.d('Parsed user settings map: $jsonMap');
    final settings = UserSettings.fromJson(jsonMap);
    logger.d('Created UserSettings: cyclingFtp=[1m${settings.cyclingFtp}[0m, rowingFtp=[1m${settings.rowingFtp}[0m');
    return settings;
  }
  
  static const String _prefsKey = 'user_settings';
}
