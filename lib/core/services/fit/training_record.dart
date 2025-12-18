import '../../models/live_data_field_value.dart';

/// Model for a single training data record
class TrainingRecord {
  final DateTime timestamp;
  final double? instantaneousPower; // Watts
  final double? instantaneousSpeed; // km/h
  final double? instantaneousCadence; // rpm
  final double? heartRate; // bpm
  final double? totalDistance; // meters (calculated)
  final double? elevation; // meters (usually 0 for indoor)
  final int elapsedTime; // seconds since start
  final double? resistanceLevel;
  final double? strokeRate; // for rower, strokes/min
  final double? totalStrokeCount; // for rower
  final double? calories; // burned calories (from Total Energy)
  final double? latitude; // GPS latitude from GPX route
  final double? longitude; // GPS longitude from GPX route
  
  const TrainingRecord({
    required this.timestamp,
    required this.elapsedTime,
    this.instantaneousPower,
    this.instantaneousSpeed,
    this.instantaneousCadence,
    this.heartRate,
    this.totalDistance,
    this.elevation = 0.0,
    this.resistanceLevel,
    this.strokeRate,
    this.totalStrokeCount,
    this.calories,
    this.latitude,
    this.longitude,
  });
  
  /// Create from FTMS parameter map (with proper types) and calculated distance
  factory TrainingRecord.fromFtmsParameters({
    required DateTime timestamp,
    required int elapsedTime,
    required Map<String, LiveDataFieldValue> ftmsParams,
    double? calculatedDistance,
    double? resistanceLevel,
    double? latitude,
    double? longitude,
    double? elevation,
  }) {
    return TrainingRecord(
      timestamp: timestamp,
      elapsedTime: elapsedTime,
      instantaneousPower: _getParameterValue(ftmsParams, 'Instantaneous Power'),
      instantaneousSpeed: _getParameterValue(ftmsParams, 'Instantaneous Speed'),
      instantaneousCadence: _getParameterValue(ftmsParams, 'Instantaneous Cadence'),
      heartRate: _getParameterValue(ftmsParams, 'Heart Rate'),
      totalDistance: calculatedDistance,
      resistanceLevel: resistanceLevel,
      strokeRate: _getParameterValue(ftmsParams, 'Stroke Rate'),
      totalStrokeCount: _getParameterValue(ftmsParams, 'Total Stroke Count'),
      calories: _getParameterValue(ftmsParams, 'Total Energy'),
      latitude: latitude,
      longitude: longitude,
      elevation: elevation,
    );
  }
  
  static double? _getParameterValue(Map<String, LiveDataFieldValue> params, String key) {
    final param = params[key];
    if (param == null) return null;
    return param.getScaledValue().toDouble();
  }
  
  @override
  String toString() {
    return 'TrainingRecord(time: ${elapsedTime}s, power: ${instantaneousPower}W, '
        'speed: ${instantaneousSpeed}km/h, distance: ${totalDistance}m, calories: ${calories}kcal, '
        'lat: $latitude, lon: $longitude)';
  }
}
