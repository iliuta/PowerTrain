import 'dart:collection';

/// A service that tracks historical values and calculates averages over specified time periods.
class ValueAveragingService {
  static final ValueAveragingService _instance = ValueAveragingService._internal();
  factory ValueAveragingService() => _instance;
  ValueAveragingService._internal();

  /// Map of field names to their historical values
  final Map<String, Queue<_TimestampedValue>> _historicalValues = {};

  /// Map of field names to their configured sample periods
  final Map<String, int> _samplePeriods = {};

  /// Configure a field for averaging
  void configureField(String fieldName, int samplePeriodSeconds) {
    _samplePeriods[fieldName] = samplePeriodSeconds;
    _historicalValues[fieldName] ??= Queue<_TimestampedValue>();
  }

  /// Add a new value for a field
  void addValue(String fieldName, dynamic value) {
    if (!_samplePeriods.containsKey(fieldName)) {
      return; // Field not configured for averaging
    }

    // Skip null values
    if (value == null) {
      return;
    }

    final queue = _historicalValues[fieldName]!;
    final now = DateTime.now();
    
    // Convert value to num for calculations
    final numValue = value is num ? value : num.tryParse(value.toString());
    if (numValue == null) {
      return; // Skip non-numeric values
    }
    
    // Add new value
    queue.add(_TimestampedValue(timestamp: now, value: numValue));

    // Clean up old values outside the sample period
    final samplePeriod = _samplePeriods[fieldName]!;
    if (samplePeriod > 0) {
      final cutoffTime = now.subtract(Duration(seconds: samplePeriod));
      while (queue.isNotEmpty && queue.first.timestamp.isBefore(cutoffTime)) {
        queue.removeFirst();
      }
    }
  }

  /// Get the averaged value for a field, or null if not configured for averaging
  num? getAveragedValue(String fieldName) {
    if (!_samplePeriods.containsKey(fieldName)) {
      return null; // Field not configured for averaging
    }

    final queue = _historicalValues[fieldName]!;
    if (queue.isEmpty) {
      return null; // No values available
    }

    // For stroke rate, use weighted average with more weight on recent values
    if (fieldName == 'Stroke Rate') {
      return _calculateWeightedAverage(queue);
    }

    // For other fields, use simple average
    final sum = queue.fold<num>(0, (sum, item) => sum + item.value);
    return sum / queue.length;
  }

  /// Calculate weighted average with exponential decay (more recent = higher weight)
  num _calculateWeightedAverage(Queue<_TimestampedValue> queue) {
    if (queue.isEmpty) return 0;

    final now = DateTime.now();
    num weightedSum = 0;
    num totalWeight = 0;

    for (final item in queue) {
      // Weight decreases exponentially with age (newer = higher weight)
      final ageSeconds = now.difference(item.timestamp).inSeconds;
      final weight = 1.0 / (1.0 + ageSeconds); // Simple decay function
      weightedSum += item.value * weight;
      totalWeight += weight;
    }

    return weightedSum / totalWeight;
  }

  /// Check if a field is configured for averaging
  bool isFieldAveraged(String fieldName) {
    return _samplePeriods.containsKey(fieldName);
  }

  /// Get the sample period for a field
  int? getSamplePeriod(String fieldName) {
    return _samplePeriods[fieldName];
  }

  /// Clear all historical data
  void clearAll() {
    _historicalValues.clear();
    _samplePeriods.clear();
  }

  /// Clear historical data for a specific field
  void clearField(String fieldName) {
    _historicalValues.remove(fieldName);
    _samplePeriods.remove(fieldName);
  }
}

/// Internal class to store timestamped values
class _TimestampedValue {
  final DateTime timestamp;
  final num value;

  _TimestampedValue({required this.timestamp, required this.value});
}
