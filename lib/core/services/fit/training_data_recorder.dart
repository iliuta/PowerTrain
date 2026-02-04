import 'dart:async';
import 'dart:io';
import 'package:ftms/core/models/device_types.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fit_tool/fit_tool.dart';
import 'training_record.dart';
import '../../models/live_data_field_value.dart';
import 'distance_calculation_strategy.dart';
import '../gpx/gpx_route_tracker.dart';
import '../../utils/logger.dart';

/// Service for recording training session data and generating FIT files
class TrainingDataRecorder {
  final List<TrainingRecord> _records = [];
  final DistanceCalculationStrategy _distanceStrategy;
  final String _sessionName;
  final DeviceType _deviceType;
  
  /// GPX route tracker for adding GPS coordinates to records
  final GpxRouteTracker? _gpxRouteTracker;

  DateTime? _sessionStartTime;
  DateTime? _lastRecordTime;
  bool _isRecording = false;

  TrainingDataRecorder({
    required DeviceType deviceType,
    String? sessionName,
    GpxRouteTracker? gpxRouteTracker,
  })  : _deviceType = deviceType,
        _sessionName =
            sessionName ?? 'Training_${DateTime.now().millisecondsSinceEpoch}',
        _distanceStrategy =
            DistanceCalculationStrategyFactory.createStrategy(deviceType),
        _gpxRouteTracker = gpxRouteTracker;

  /// Start recording training data
  void startRecording() {
    if (_isRecording) return;

    _sessionStartTime = DateTime.now();
    _lastRecordTime = _sessionStartTime;
    _isRecording = true;
    _records.clear();
    _distanceStrategy.reset();
    _gpxRouteTracker?.reset();

    logger.i('Started recording training session: $_sessionName');
  }

  /// Stop recording training data
  void stopRecording() {
    _isRecording = false;
    logger.i(
        'Stopped recording training session: $_sessionName (${_records.length} records)');
  }

  /// Add a new data point from FTMS device
  void recordDataPoint({
    required Map<String, LiveDataFieldValue> ftmsParams,
    double? resistanceLevel,
    DateTime? timestamp, // Optional timestamp for testing
  }) {
    if (!_isRecording || _sessionStartTime == null) return;

    final now = timestamp ?? DateTime.now();
    final elapsedTime = now.difference(_sessionStartTime!).inSeconds;
    final timeDelta = _lastRecordTime != null
        ? now.difference(_lastRecordTime!).inMilliseconds / 1000.0
        : 1.0;

    // Calculate distance increment
    final previousData =
        _records.isNotEmpty ? _convertRecordToMap(_records.last) : null;

    final distanceIncrement = _distanceStrategy.calculateDistanceIncrement(
      currentData: ftmsParams,
      previousData: previousData,
      timeDeltaSeconds: timeDelta,
    );

    // Update GPX position based on distance traveled
    double? latitude;
    double? longitude;
    double? elevation;
    
    if (_gpxRouteTracker != null && _gpxRouteTracker.isLoaded) {
      final position = _gpxRouteTracker.updatePosition(distanceIncrement);
      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;
        elevation = position.elevation;
      }
    }

    // Create training record
    final record = TrainingRecord.fromFtmsParameters(
      timestamp: now,
      elapsedTime: elapsedTime,
      ftmsParams: ftmsParams,
      calculatedDistance: _distanceStrategy.totalDistance,
      resistanceLevel: resistanceLevel,
      latitude: latitude,
      longitude: longitude,
      elevation: elevation,
    );

    _records.add(record);
    _lastRecordTime = now;

    // Log occasionally to track progress
    if (_records.length % 60 == 0) {
      // Every 60 records (roughly 1 minute)
      final posInfo = latitude != null ? ', pos: ($latitude, $longitude)' : '';
      logger.i(
          'Recorded ${_records.length} data points, distance: ${_distanceStrategy.totalDistance.toStringAsFixed(1)}m$posInfo');
    }
  }

  Map<String, LiveDataFieldValue> _convertRecordToMap(TrainingRecord record) {
    final convertedMap = <String, LiveDataFieldValue>{};

    if (record.instantaneousPower != null) {
      convertedMap['Instantaneous Power'] = LiveDataFieldValue(
        name: 'Instantaneous Power',
        value: record.instantaneousPower!,
        unit: 'W',
      );
    }

    if (record.instantaneousSpeed != null) {
      convertedMap['Instantaneous Speed'] = LiveDataFieldValue(
        name: 'Instantaneous Speed',
        value: record.instantaneousSpeed!,
        unit: 'km/h',
      );
    }

    if (record.instantaneousCadence != null) {
      convertedMap['Instantaneous Cadence'] = LiveDataFieldValue(
        name: 'Instantaneous Cadence',
        value: record.instantaneousCadence!,
        unit: 'rpm',
      );
    }

    if (record.heartRate != null) {
      convertedMap['Heart Rate'] = LiveDataFieldValue(
        name: 'Heart Rate',
        value: record.heartRate!,
        unit: 'bpm',
      );
    }

    if (record.strokeRate != null) {
      convertedMap['Stroke Rate'] = LiveDataFieldValue(
        name: 'Stroke Rate',
        value: record.strokeRate!,
        unit: 'spm',
      );
    }

    if (record.calories != null) {
      convertedMap['Total Energy'] = LiveDataFieldValue(
        name: 'Total Energy',
        value: record.calories!,
        unit: 'kcal',
      );
    }

    return convertedMap;
  }

  /// Generate and save FIT file
  Future<String?> generateFitFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final fitDir = Directory('${directory.path}/fit_files');
    return generateFitFileToDirectory(fitDir);
  }

  /// Generate and save FIT file to a specific directory
  Future<String?> generateFitFileToDirectory(Directory outputDirectory) async {
    if (_records.isEmpty || _sessionStartTime == null) {
      logger.w('No training data to export');
      return null;
    }

    try {
      // Ensure output directory exists
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
      }

      final filename =
          '${_sessionName}_${_formatDateForFilename(_sessionStartTime!)}.fit';
      final filePath = '${outputDirectory.path}/$filename';

      logger.i('Generating FIT file: $filePath');

      // Create FIT file content
      final fitFile = await _createFitFile();

      // Write to file
      final file = File(filePath);
      await file.writeAsBytes(fitFile);

      logger.i(
          'FIT file generated successfully: $filePath (${_records.length} records)');
      return filePath;
    } catch (e, stackTrace) {
      logger.e('Failed to generate FIT file: $e\nStack trace: $stackTrace');
      return null;
    }
  }

  String _formatDateForFilename(DateTime dateTime) {
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}_'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<List<int>> _createFitFile() async {
    // Use autoDefine: true so the builder creates Definition Messages automatically
    final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);

    final startTimestamp = _sessionStartTime!.millisecondsSinceEpoch;
    final endTimestamp = _records.last.timestamp.millisecondsSinceEpoch;
    // Elapsed time in seconds (FIT expects seconds, not milliseconds)
    final elapsedTimeSeconds = (endTimestamp - startTimestamp) / 1000.0;

    // 1. File ID message (must be first)
    final fileIdMessage = FileIdMessage()
      ..type = FileType.activity
      ..timeCreated = startTimestamp
      ..manufacturer = Manufacturer.development.value
      ..product = 1 
      ..productName = 'RowerTrain mobile application'
      ..serialNumber = 0x12345678;
    builder.add(fileIdMessage);

    // 2. Timer start event (best practice for FIT activity files)
    final startEventMessage = EventMessage()
      ..event = Event.timer
      ..eventType = EventType.start
      ..timestamp = startTimestamp;
    builder.add(startEventMessage);

    // 3. Record messages for each data point
    // Skip records with duplicate second-level timestamps to avoid FIT file issues
    final recordMessages = <RecordMessage>[];
    int? lastTimestampSeconds;
    
    for (int i = 0; i < _records.length; i++) {
      final record = _records[i];
      final timestampSeconds = record.timestamp.millisecondsSinceEpoch ~/ 1000;
      
      // Skip if this record has the same second-level timestamp as the previous one
      if (lastTimestampSeconds != null && timestampSeconds == lastTimestampSeconds) {
        continue;
      }
      lastTimestampSeconds = timestampSeconds;
      
      // For rowing, use stroke rate as cadence; for cycling, use instantaneous cadence
      int? cadenceValue;
      if (_deviceType == DeviceType.rower) {
        cadenceValue = record.strokeRate?.round();
      } else {
        cadenceValue = record.instantaneousCadence?.round();
      }
      
      final recordMessage = RecordMessage()
        ..timestamp = record.timestamp.millisecondsSinceEpoch
        ..power = record.instantaneousPower?.round()
        ..speed = record.instantaneousSpeed != null
            ? (record.instantaneousSpeed! / 3.6).toDouble() // Convert km/h to m/s
            : null
        ..cadence = cadenceValue
        ..heartRate = record.heartRate?.round()
        ..distance = (record.totalDistance != null)
            ? (record.totalDistance!).toDouble()
            : null
        ..calories = record.calories?.round()
        ..positionLat = record.latitude
        ..positionLong = record.longitude
        ..altitude = record.elevation?.toDouble();

      recordMessages.add(recordMessage);
    }
    builder.addAll(recordMessages);

    // 4. Timer stop event
    final stopEventMessage = EventMessage()
      ..event = Event.timer
      ..eventType = EventType.stop
      ..timestamp = endTimestamp;
    builder.add(stopEventMessage);

    // Get start and end positions for session/lap
    final startPosition = _getStartPosition();
    final endPosition = _getEndPosition();

    // 5. Lap message (every FIT activity file MUST contain at least one Lap)
    final lapMessage = LapMessage()
      ..timestamp = endTimestamp
      ..startTime = startTimestamp
      ..totalElapsedTime = elapsedTimeSeconds
      ..totalTimerTime = elapsedTimeSeconds
      ..totalDistance = _getTotalDistance()?.toDouble()
      ..avgPower = _getAveragePower()
      ..maxPower = _getMaximumPower()
      ..avgSpeed = _getAverageSpeed()
      ..maxSpeed = _getMaximumSpeed()
      ..avgHeartRate = _getAverageHeartRate()
      ..maxHeartRate = _getMaximumHeartRate()
      ..avgCadence = _getAverageCadence()
      ..maxCadence = _getMaximumCadence()
      ..totalCalories = _getTotalCalories()
      ..startPositionLat = startPosition?.$1
      ..startPositionLong = startPosition?.$2
      ..endPositionLat = endPosition?.$1
      ..endPositionLong = endPosition?.$2;
    builder.add(lapMessage);

    // 6. Session message (every FIT activity file MUST contain at least one Session)
    final sessionMessage = SessionMessage()
      ..timestamp = endTimestamp
      ..sport = _getSport()
      ..subSport = _getSubSport()
      ..startTime = startTimestamp
      ..totalElapsedTime = elapsedTimeSeconds
      ..totalTimerTime = elapsedTimeSeconds
      ..totalDistance = _getTotalDistance()?.toDouble()
      ..avgPower = _getAveragePower()
      ..maxPower = _getMaximumPower()
      ..avgSpeed = _getAverageSpeed()
      ..maxSpeed = _getMaximumSpeed()
      ..avgHeartRate = _getAverageHeartRate()
      ..maxHeartRate = _getMaximumHeartRate()
      ..avgCadence = _getAverageCadence()
      ..maxCadence = _getMaximumCadence()
      ..totalCalories = _getTotalCalories()
      ..startPositionLat = startPosition?.$1
      ..startPositionLong = startPosition?.$2
      ..firstLapIndex = 0
      ..numLaps = 1;
    builder.add(sessionMessage);

    // 7. Activity message (summary of the activity)
    final activityMessage = ActivityMessage()
      ..timestamp = endTimestamp
      ..totalTimerTime = elapsedTimeSeconds
      ..numSessions = 1
      ..type = Activity.manual
      ..event = Event.activity
      ..eventType = EventType.stop;
    builder.add(activityMessage);

    final fitFile = builder.build();
    return fitFile.toBytes();
  }

  Sport _getSport() {
    switch (_deviceType) {
      case DeviceType.indoorBike:
        return Sport.cycling;
      case DeviceType.rower:
        return Sport.rowing;
    }
  }

  SubSport _getSubSport() {
    // Use virtual/outdoor subsports when GPS data is available to show map on Strava
    // Indoor subsports cause Strava to ignore GPS coordinates
    final hasGpsData = _records.any((r) => r.latitude != null && r.longitude != null);
    
    switch (_deviceType) {
      case DeviceType.indoorBike:
        return hasGpsData ? SubSport.virtualActivity : SubSport.indoorCycling;
      case DeviceType.rower:
        // For rowing with GPS, use generic subsport (outdoor rowing simulation)
        // return hasGpsData ? SubSport.generic : SubSport.indoorRowing;
        return SubSport.indoorRowing;
    }
  }

  /// Get the start position (first record with GPS data) in degrees
  (double, double)? _getStartPosition() {
    final firstWithGps = _records.where((r) => r.latitude != null && r.longitude != null).firstOrNull;
    if (firstWithGps == null) return null;
    return (firstWithGps.latitude!, firstWithGps.longitude!);
  }

  /// Get the end position (last record with GPS data) in degrees
  (double, double)? _getEndPosition() {
    final lastWithGps = _records.where((r) => r.latitude != null && r.longitude != null).lastOrNull;
    if (lastWithGps == null) return null;
    return (lastWithGps.latitude!, lastWithGps.longitude!);
  }

  int? _getTotalDistance() {
    return _distanceStrategy.totalDistance.round();
  }

  int? _getAveragePower() {
    final powers = _records
        .where((r) => r.instantaneousPower != null && r.instantaneousPower! > 0)
        .map((r) => r.instantaneousPower!)
        .toList();
    if (powers.isEmpty) return null;
    return (powers.reduce((a, b) => a + b) / powers.length).round();
  }

  int? _getMaximumPower() {
    final powers = _records
        .where((r) => r.instantaneousPower != null)
        .map((r) => r.instantaneousPower!)
        .toList();
    if (powers.isEmpty) return null;
    return powers.reduce((a, b) => a > b ? a : b).round();
  }

  double? _getAverageSpeed() {
    final speeds = _records
        .where((r) => r.instantaneousSpeed != null && r.instantaneousSpeed! > 0)
        .map((r) => r.instantaneousSpeed!)
        .toList();
    if (speeds.isEmpty) return null;
    // Convert km/h to mm/s for FIT format
    return (speeds.reduce((a, b) => a + b) / speeds.length) * 1000 / 3.6;
  }

  double? _getMaximumSpeed() {
    final speeds = _records
        .where((r) => r.instantaneousSpeed != null)
        .map((r) => r.instantaneousSpeed!)
        .toList();
    if (speeds.isEmpty) return null;
    // Convert km/h to mm/s for FIT format
    return speeds.reduce((a, b) => a > b ? a : b) * 1000 / 3.6;
  }

  int? _getAverageHeartRate() {
    final heartRates = _records
        .where((r) => r.heartRate != null && r.heartRate! > 0)
        .map((r) => r.heartRate!)
        .toList();
    if (heartRates.isEmpty) return null;
    return (heartRates.reduce((a, b) => a + b) / heartRates.length).round();
  }

  int? _getMaximumHeartRate() {
    final heartRates = _records
        .where((r) => r.heartRate != null)
        .map((r) => r.heartRate!)
        .toList();
    if (heartRates.isEmpty) return null;
    return heartRates.reduce((a, b) => a > b ? a : b).round();
  }

  int? _getAverageCadence() {
    final cadences = _records
        .where((r) =>
            r.instantaneousCadence != null && r.instantaneousCadence! > 0)
        .map((r) => r.instantaneousCadence!)
        .toList();
    if (cadences.isEmpty) return null;
    return (cadences.reduce((a, b) => a + b) / cadences.length).round();
  }

  int? _getMaximumCadence() {
    final cadences = _records
        .where((r) => r.instantaneousCadence != null)
        .map((r) => r.instantaneousCadence!)
        .toList();
    if (cadences.isEmpty) return null;
    return cadences.reduce((a, b) => a > b ? a : b).round();
  }

  /// Get total calories from the last record (cumulative)
  int? _getTotalCalories() {
    // Find the last record with calories data
    final lastRecordWithCalories = _records.lastWhere(
      (r) => r.calories != null && r.calories! > 0,
      orElse: () => _records.last,
    );
    
    if (lastRecordWithCalories.calories == null) return null;
    return lastRecordWithCalories.calories!.round();
  }

  /// Get current statistics
  Map<String, dynamic> getStatistics() {
    if (_records.isEmpty) return {};

    return {
      'recordCount': _records.length,
      'duration': _records.last.elapsedTime,
      'totalDistance': _distanceStrategy.totalDistance,
      'averagePower': _getAveragePower(),
      'maxPower': _getMaximumPower(),
      'averageSpeed': _getAverageSpeed(),
      'maxSpeed': _getMaximumSpeed(),
      'averageHeartRate': _getAverageHeartRate(),
      'maxHeartRate': _getMaximumHeartRate(),
      'averageCadence': _getAverageCadence(),
      'maxCadence': _getMaximumCadence(),
    };
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get number of recorded data points
  int get recordCount => _records.length;

  /// Get session name
  String get sessionName => _sessionName;
}
