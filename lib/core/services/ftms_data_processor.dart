import 'package:flutter_ftms/flutter_ftms.dart';
import '../config/live_data_display_config.dart';
import '../models/live_data_field_value.dart';
import 'value_averaging_service.dart';
import 'devices/heart_rate_service.dart';
import 'devices/cadence_service.dart';

/// Service for processing FTMS device data with averaging capabilities.
/// Can be used by both FTMSDataTab and training sessions.
/// 
/// Note: Packet merging (for split packets) is handled by flutter_ftms,
/// so this service always receives complete DeviceData packets.
class FtmsDataProcessor {
  final ValueAveragingService _averagingService = ValueAveragingService();
  final HeartRateService _heartRateService = HeartRateService();
  final CadenceService _cadenceService = CadenceService();
  bool _isConfigured = false;
  LiveDataDisplayConfig? _config;
  final Map<String, double> _cumulativeValues = {};
  final Map<String, double> _cumulativeOffsets = {};

  /// Configure the processor with display config to set up averaging fields
  void configure(LiveDataDisplayConfig config) {
    if (_isConfigured) return; // Avoid reconfiguring
    
    _config = config;
    for (final field in config.fields) {
      if (field.samplePeriodSeconds != null) {
        _averagingService.configureField(field.name, field.samplePeriodSeconds!);
      }
      
      // Initialize cumulative fields
      if (field.isCumulative) {
        _cumulativeValues[field.name] = 0.0;
        _cumulativeOffsets[field.name] = 0.0;
      }
    }
    _isConfigured = true;
  }

  /// Process raw FTMS device data and return paramValueMap with averaging applied
  Map<String, LiveDataFieldValue> processDeviceData(DeviceData deviceData) {
    final parameterValues = deviceData.getDeviceDataParameterValues();
    
    // Create initial param value map using FtmsParameter model
    final Map<String, LiveDataFieldValue> rawParamValueMap = {
      for (final p in parameterValues)
        p.name.name: LiveDataFieldValue.fromDeviceDataParameterValue(p)
    };
    
    // Process values for averaging and create final param value map
    final Map<String, LiveDataFieldValue> paramValueMap = {};
    for (final entry in rawParamValueMap.entries) {
      final fieldName = entry.key;
      final param = entry.value;
      
      // Add raw value to averaging service
      _averagingService.addValue(fieldName, param.value);
      
      // Check if this is a cumulative field
      final fieldConfig = _config?.fields.where(
        (field) => field.name == fieldName,
      ).firstOrNull;
      
      if (fieldConfig?.isCumulative == true) {
        // Handle cumulative fields
        _processCumulativeField(fieldName, paramValueMap, param);
      } else {
        // Use averaged value if configured, otherwise use raw value
        _useAveragedValueIfConfigured(fieldName, paramValueMap, param);
      }
    }
    
    // Override heart rate with HRM data if available
    _overrideHeartRateFromHRMIfAvailable(paramValueMap);
    
    // Override cadence with cadence sensor data if available
    _overrideCadenceFromCadenceSensorIfAvailable(paramValueMap);
    
    return paramValueMap;
  }
  
  void _processCumulativeField(String fieldName, Map<String, LiveDataFieldValue> paramValueMap, LiveDataFieldValue param) {
    final currentRawValue = param.getScaledValue();
    final storedValue = _cumulativeValues[fieldName] ?? 0.0;
    final currentOffset = _cumulativeOffsets[fieldName] ?? 0.0;
    
    // If current raw value is greater than or equal to stored value, this is normal increment
    if (currentRawValue >= storedValue) {
      // Normal case: just use the raw value plus any offset from previous resets
      _cumulativeValues[fieldName] = currentRawValue.toDouble();
      final finalValue = currentRawValue + currentOffset;
      paramValueMap[fieldName] = param.copyWith(value: finalValue);
    } else {
      // Current raw value is lower than stored value - potential reset detected
      final dropPercentage = (storedValue - currentRawValue) / storedValue;
      if (dropPercentage > 0.5) { 
        // Significant drop detected - device likely reset
        // Add the previous total (stored + offset) to the offset for future calculations
        _cumulativeOffsets[fieldName] = storedValue + currentOffset;
        _cumulativeValues[fieldName] = currentRawValue.toDouble();
        final finalValue = currentRawValue + _cumulativeOffsets[fieldName]!;
        paramValueMap[fieldName] = param.copyWith(value: finalValue);
      } else {
        // Small decrease, maintain previous total value
        final finalValue = storedValue + currentOffset;
        paramValueMap[fieldName] = param.copyWith(value: finalValue);
      }
    }
  }

  void _useAveragedValueIfConfigured(String fieldName, Map<String, LiveDataFieldValue> paramValueMap, LiveDataFieldValue param) {
    if (_averagingService.isFieldAveraged(fieldName)) {
      final averagedValue = _averagingService.getAveragedValue(fieldName);
      if (averagedValue != null) {
        // Create a new parameter with averaged value
        paramValueMap[fieldName] = param.copyWith(value: averagedValue);
      } else {
        paramValueMap[fieldName] = param;
      }
    } else {
      paramValueMap[fieldName] = param;
    }
  }

  void _overrideHeartRateFromHRMIfAvailable(Map<String, LiveDataFieldValue> paramValueMap) {
    if (_heartRateService.isHrmConnected && _heartRateService.currentHeartRate != null) {
      // Check if Heart Rate field exists in the configuration
      if (paramValueMap.containsKey('Heart Rate')) {
        // Replace with HRM data, keeping the same configuration as the FTMS heart rate field
        final originalHeartRateParam = paramValueMap['Heart Rate']!;
        paramValueMap['Heart Rate'] = originalHeartRateParam.copyWith(
          value: _heartRateService.currentHeartRate!.toDouble(),
        );
      } else {
        // Add HRM heart rate data if not present in FTMS data
        paramValueMap['Heart Rate'] = LiveDataFieldValue(
          name: 'Heart Rate',
          value: _heartRateService.currentHeartRate!.toDouble(),
          unit: 'bpm',
          factor: 1,
        );
      }
    }
  }

  void _overrideCadenceFromCadenceSensorIfAvailable(Map<String, LiveDataFieldValue> paramValueMap) {
    if (_cadenceService.isCadenceConnected && _cadenceService.currentCadence != null) {
      // Check if Instantaneous Cadence field exists in the configuration
      if (paramValueMap.containsKey('Instantaneous Cadence')) {
        // Replace with cadence sensor data, but use factor 1 since cadence sensor already provides correct RPM
        final originalCadenceParam = paramValueMap['Instantaneous Cadence']!;
        paramValueMap['Instantaneous Cadence'] = originalCadenceParam.copyWith(
          value: _cadenceService.currentCadence!.toDouble(),
          factor: 1, // Always use factor 1 for cadence sensor data
        );
      } else {
        // Add cadence sensor data if not present in FTMS data
        paramValueMap['Instantaneous Cadence'] = LiveDataFieldValue(
          name: 'Instantaneous Cadence',
          value: _cadenceService.currentCadence!.toDouble(),
          unit: 'rpm',
          factor: 1,
        );
      }
    }
  }

  /// Reset the processor state (useful for testing or switching devices)
  void reset() {
    _isConfigured = false;
    _config = null;
    _cumulativeValues.clear();
    _cumulativeOffsets.clear();
    // Clear the averaging service data when resetting
    _averagingService.clearAll();
  }
}
