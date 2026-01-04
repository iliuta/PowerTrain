import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:ftms/core/models/device_types.dart';

/// Analytics service for tracking user interactions and feature usage.
/// 
/// This service wraps Firebase Analytics and provides typed methods
/// for tracking all training-related events in the app.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  
  factory AnalyticsService() => _instance;
  
  AnalyticsService._internal();
  
  FirebaseAnalytics? _analytics;
  
  /// Initialize the analytics service.
  /// Must be called after Firebase.initializeApp()
  void initialize() {
    _analytics = FirebaseAnalytics.instance;
  }
  
  /// Whether analytics is available
  bool get isInitialized => _analytics != null;
  
  // ============ Training Session Events ============
  
  /// Track when a user creates a new training session
  Future<void> logTrainingSessionCreated({
    required DeviceType machineType,
    required bool isDistanceBased,
    required int intervalCount,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_created',
      parameters: {
        'machine_type': machineType.name,
        'is_distance_based': isDistanceBased.toString(),
        'interval_count': intervalCount,
      },
    );
  }
  
  /// Track when a user edits an existing training session
  Future<void> logTrainingSessionEdited({
    required DeviceType machineType,
    required bool isDistanceBased,
    required int intervalCount,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_edited',
      parameters: {
        'machine_type': machineType.name,
        'is_distance_based': isDistanceBased.toString(),
        'interval_count': intervalCount,
      },
    );
  }
  
  /// Track when a user deletes a training session
  Future<void> logTrainingSessionDeleted({
    required DeviceType machineType,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_deleted',
      parameters: {
        'machine_type': machineType.name,
      },
    );
  }
  
  /// Track when a user starts a training session
  Future<void> logTrainingSessionStarted({
    required DeviceType machineType,
    required bool isDistanceBased,
    required bool isFreeRide,
    required int totalDurationSeconds,
    int? totalDistanceMeters,
    required int intervalCount,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_started',
      parameters: {
        'machine_type': machineType.name,
        'is_distance_based': isDistanceBased.toString(),
        'is_free_ride': isFreeRide.toString(),
        'total_duration_seconds': totalDurationSeconds,
        if (totalDistanceMeters != null) 'total_distance_meters': totalDistanceMeters,
        'interval_count': intervalCount,
      },
    );
  }
  
  /// Track when a user completes a training session (reaches the end naturally)
  Future<void> logTrainingSessionCompleted({
    required DeviceType machineType,
    required bool isDistanceBased,
    required bool isFreeRide,
    required int elapsedTimeSeconds,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_completed',
      parameters: {
        'machine_type': machineType.name,
        'is_distance_based': isDistanceBased.toString(),
        'is_free_ride': isFreeRide.toString(),
        'elapsed_time_seconds': elapsedTimeSeconds,
      },
    );
  }
  
  /// Track when a user cancels/stops a training session before completion
  Future<void> logTrainingSessionCancelled({
    required DeviceType machineType,
    required bool isDistanceBased,
    required bool isFreeRide,
    required int elapsedTimeSeconds,
    required int totalDurationSeconds,
    required double completionPercentage,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_cancelled',
      parameters: {
        'machine_type': machineType.name,
        'is_distance_based': isDistanceBased.toString(),
        'is_free_ride': isFreeRide.toString(),
        'elapsed_time_seconds': elapsedTimeSeconds,
        'total_duration_seconds': totalDurationSeconds,
        'completion_percentage': completionPercentage.round(),
      },
    );
  }
  
  /// Track when a user pauses a training session
  Future<void> logTrainingSessionPaused({
    required DeviceType machineType,
    required bool isFreeRide,
    required int elapsedTimeSeconds,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_paused',
      parameters: {
        'machine_type': machineType.name,
        'is_free_ride': isFreeRide.toString(),
        'elapsed_time_seconds': elapsedTimeSeconds,
      },
    );
  }
  
  /// Track when a user resumes a training session
  Future<void> logTrainingSessionResumed({
    required DeviceType machineType,
    required bool isFreeRide,
    required int elapsedTimeSeconds,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_resumed',
      parameters: {
        'machine_type': machineType.name,
        'is_free_ride': isFreeRide.toString(),
        'elapsed_time_seconds': elapsedTimeSeconds,
      },
    );
  }
  
  /// Track when a user extends a training session after completion
  Future<void> logTrainingSessionExtended({
    required DeviceType machineType,
    required bool isFreeRide,
    required int elapsedTimeSeconds,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_extended',
      parameters: {
        'machine_type': machineType.name,
        'is_free_ride': isFreeRide.toString(),
        'elapsed_time_seconds': elapsedTimeSeconds,
      },
    );
  }
  
  // ============ Free Ride Events ============
  
  /// Track when a user starts a free ride session
  Future<void> logFreeRideStarted({
    required DeviceType machineType,
    required bool isDistanceBased,
    required int targetValue, // duration in seconds or distance in meters
    required bool hasWarmup,
    required bool hasCooldown,
    int? resistanceLevel,
    required bool hasGpxRoute,
  }) async {
    await _analytics?.logEvent(
      name: 'free_ride_started',
      parameters: {
        'machine_type': machineType.name,
        'is_distance_based': isDistanceBased.toString(),
        'target_value': targetValue,
        'has_warmup': hasWarmup.toString(),
        'has_cooldown': hasCooldown.toString(),
        if (resistanceLevel != null) 'resistance_level': resistanceLevel,
        'has_gpx_route': hasGpxRoute.toString(),
      },
    );
  }
  
  // ============ Feature Usage Events ============
  
  /// Track when a user views the training sessions list
  Future<void> logTrainingSessionsViewed({
    required DeviceType machineType,
    required int sessionCount,
  }) async {
    await _analytics?.logEvent(
      name: 'training_sessions_viewed',
      parameters: {
        'machine_type': machineType.name,
        'session_count': sessionCount,
      },
    );
  }
  
  /// Track when a user selects a training session from the list
  Future<void> logTrainingSessionSelected({
    required DeviceType machineType,
    required String sessionTitle,
    required bool isCustom,
    required bool isDistanceBased,
  }) async {
    await _analytics?.logEvent(
      name: 'training_session_selected',
      parameters: {
        'machine_type': machineType.name,
        'session_title': _truncateString(sessionTitle, 100),
        'is_custom': isCustom.toString(),
        'is_distance_based': isDistanceBased.toString(),
      },
    );
  }
  
  /// Track when a FIT file is saved
  Future<void> logFitFileSaved({
    required DeviceType machineType,
    required int durationSeconds,
    int? distanceMeters,
  }) async {
    await _analytics?.logEvent(
      name: 'fit_file_saved',
      parameters: {
        'machine_type': machineType.name,
        'duration_seconds': durationSeconds,
        if (distanceMeters != null) 'distance_meters': distanceMeters,
      },
    );
  }
  
  /// Track when a workout is uploaded to Strava
  Future<void> logStravaUpload({
    required DeviceType machineType,
    required bool success,
    required int durationSeconds,
  }) async {
    await _analytics?.logEvent(
      name: 'strava_upload',
      parameters: {
        'machine_type': machineType.name,
        'success': success.toString(),
        'duration_seconds': durationSeconds,
      },
    );
  }
  
  /// Track device connection
  Future<void> logDeviceConnected({
    required String deviceType,
    required String deviceName,
  }) async {
    await _analytics?.logEvent(
      name: 'device_connected',
      parameters: {
        'machine_type': deviceType,
        'device_name': _truncateString(deviceName, 100),
      },
    );
  }
  
  /// Track device disconnection
  Future<void> logDeviceDisconnected({
    required String deviceType,
    required String deviceName,
  }) async {
    await _analytics?.logEvent(
      name: 'device_disconnected',
      parameters: {
        'machine_type': deviceType,
        'device_name': _truncateString(deviceName, 100),
      },
    );
  }
  
  // ============ Screen Tracking ============
  
  /// Track screen views for better understanding of user navigation
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics?.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }
  

  // ============ Helper Methods ============
  
  /// Truncate string to fit Firebase Analytics limits (100 chars for param values)
  String _truncateString(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
