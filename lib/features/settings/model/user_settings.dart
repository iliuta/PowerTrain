import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ftms/core/utils/logger.dart';

class UserSettings {
  final int cyclingFtp;
  final String rowingFtp;
  final bool developerMode;
  final bool soundEnabled;

  const UserSettings({
    required this.cyclingFtp,
    required this.rowingFtp,
    required this.developerMode,
    required this.soundEnabled,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      cyclingFtp: json['cyclingFtp'] as int,
      rowingFtp: json['rowingFtp'] as String,
      developerMode: json['developerMode'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cyclingFtp': cyclingFtp,
      'rowingFtp': rowingFtp,
      'developerMode': developerMode,
      'soundEnabled': soundEnabled,
    };
  }

  static const String _prefsKey = 'user_settings';

  static Future<UserSettings> loadDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      
      if (jsonString != null) {
        logger.d('Loading user settings from SharedPreferences');
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        return UserSettings.fromJson(jsonMap);
      } else {
        logger.d('No saved user settings found, loading defaults from asset');
        return await _loadFromAsset();
      }
    } catch (e) {
      logger.w('Failed to load user settings from SharedPreferences, falling back to asset: $e');
      try {
        return await _loadFromAsset();
      } catch (assetError) {
        logger.e('Failed to load default user settings from asset: $assetError');
        // Return sensible defaults if all else fails
        return const UserSettings(
          cyclingFtp: 250,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
        );
      }
    }
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

  /// Save settings to SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(toJson());
      await prefs.setString(_prefsKey, jsonString);
      logger.d('User settings saved to SharedPreferences');
    } catch (e) {
      logger.e('Failed to save user settings: $e');
      throw Exception('Failed to save user settings: $e');
    }
  }

  /// Get the value of a user setting by its name
  /// Returns the setting value in its appropriate format (parsed if necessary)
  dynamic getSettingValue(String settingName) {
    switch (settingName) {
      case 'cyclingFtp':
        return cyclingFtp;
      case 'rowingFtp':
        // Parse rowing FTP if it's a string representation
        if (rowingFtp.contains(':')) {
          // Parse mm:ss format to seconds
          final parts = rowingFtp.split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }
        return double.tryParse(rowingFtp);
      case 'developerMode':
        return developerMode;
      case 'soundEnabled':
        return soundEnabled;
      default:
        return null;
    }
  }
}
