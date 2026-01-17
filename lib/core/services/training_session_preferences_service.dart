import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ftms/core/models/device_types.dart';

class TrainingSessionPreferences {
  final DeviceType deviceType;
  final Map<String, dynamic> targets;
  final int? resistanceLevel;

  TrainingSessionPreferences({
    required this.deviceType,
    required this.targets,
    this.resistanceLevel,
  });

  Map<String, dynamic> toJson() => {
    'deviceType': deviceType.name,
    'targets': targets,
    'resistanceLevel': resistanceLevel,
  };

  factory TrainingSessionPreferences.fromJson(Map<String, dynamic> json) {
    return TrainingSessionPreferences(
      deviceType: DeviceType.values.firstWhere(
        (type) => type.name == json['deviceType'],
        orElse: () => DeviceType.rower,
      ),
      targets: json['targets'] as Map<String, dynamic>? ?? {},
      resistanceLevel: json['resistanceLevel'] as int?,
    );
  }

  /// Validates that the preferences are compatible with the given device type.
  /// Returns true if compatible, false otherwise.
  bool isCompatibleWith(DeviceType requestedDeviceType) {
    return deviceType == requestedDeviceType;
  }
}

class TrainingSessionPreferencesService {
  static const String _freeRideKeyPrefix = 'training_session_free_ride_';
  static const String _trainingGeneratorKeyPrefix = 'training_session_generator_';

  /// Load free ride preferences for a specific device type
  static Future<TrainingSessionPreferences> loadFreeRidePreferences(DeviceType deviceType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_freeRideKeyPrefix${deviceType.name}';
    final json = prefs.getString(key);
    
    if (json == null) {
      return TrainingSessionPreferences(
        deviceType: deviceType,
        targets: {},
      );
    }
    
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final preferences = TrainingSessionPreferences.fromJson(decoded);
      
      // Validate device type compatibility
      if (!preferences.isCompatibleWith(deviceType)) {
        return TrainingSessionPreferences(
          deviceType: deviceType,
          targets: {},
        );
      }
      
      return preferences;
    } catch (e) {
      return TrainingSessionPreferences(
        deviceType: deviceType,
        targets: {},
      );
    }
  }

  /// Load training generator preferences for a specific device type
  static Future<TrainingSessionPreferences> loadTrainingGeneratorPreferences(DeviceType deviceType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_trainingGeneratorKeyPrefix${deviceType.name}';
    final json = prefs.getString(key);
    
    if (json == null) {
      return TrainingSessionPreferences(
        deviceType: deviceType,
        targets: {},
      );
    }
    
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final preferences = TrainingSessionPreferences.fromJson(decoded);
      
      // Validate device type compatibility
      if (!preferences.isCompatibleWith(deviceType)) {
        return TrainingSessionPreferences(
          deviceType: deviceType,
          targets: {},
        );
      }
      
      return preferences;
    } catch (e) {
      return TrainingSessionPreferences(
        deviceType: deviceType,
        targets: {},
      );
    }
  }

  /// Save free ride preferences for a specific device type
  static Future<void> saveFreeRidePreferences(
    DeviceType deviceType,
    TrainingSessionPreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_freeRideKeyPrefix${deviceType.name}';
    await prefs.setString(key, jsonEncode(preferences.toJson()));
  }

  /// Save training generator preferences for a specific device type
  static Future<void> saveTrainingGeneratorPreferences(
    DeviceType deviceType,
    TrainingSessionPreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_trainingGeneratorKeyPrefix${deviceType.name}';
    await prefs.setString(key, jsonEncode(preferences.toJson()));
  }

  /// Clear all preferences for a specific device type
  static Future<void> clearPreferences(DeviceType deviceType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_freeRideKeyPrefix${deviceType.name}');
    await prefs.remove('$_trainingGeneratorKeyPrefix${deviceType.name}');
  }
}
