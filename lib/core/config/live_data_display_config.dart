import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/utils/logger.dart';

/// Configuration for displaying live data fields in the UI from the FTMS devices
class LiveDataDisplayConfig {
  /// Corresponding FTMS machine type, e.g. 'rowingMachine', 'indoorBike'.
  final DeviceType deviceType;

  final List<LiveDataFieldConfig> fields;

  LiveDataDisplayConfig({required this.fields, required this.deviceType});

  factory LiveDataDisplayConfig.fromJson(Map<String, dynamic> json) {
    final ftmsMachineType = DeviceType.fromString(json['ftmsMachineType']);
    final fieldsJson = json['fields'] as List<dynamic>?;
    if (fieldsJson == null) {
      throw Exception('No fields in config');
    }
    final fields = fieldsJson
        .map((f) => LiveDataFieldConfig.fromJson(f as Map<String, dynamic>))
        .toList();
    return LiveDataDisplayConfig(
        fields: fields, deviceType: ftmsMachineType);
  }

  static final Map<DeviceType, Future<LiveDataDisplayConfig?>> _configCache = {};

  static Future<LiveDataDisplayConfig?> loadForFtmsMachineType(DeviceType deviceType) {

    if (_configCache.containsKey(deviceType)) {
      return _configCache[deviceType]!;
    }
    final future = _loadConfig(deviceType);
    _configCache[deviceType] = future;
    return future;
  }

  static Future<LiveDataDisplayConfig?> _loadConfig(DeviceType deviceType) async {
    String? configFile;
    switch (deviceType) {
      case DeviceType.rower:
        configFile = 'lib/config/rowing_machine.json';
        break;
      case DeviceType.indoorBike:
        configFile = 'lib/config/indoor_bike.json';
        break;
    }
    try {
      final jsonString = await rootBundle.loadString(configFile);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return LiveDataDisplayConfig.fromJson(jsonMap);
    } catch (e) {
      logger.e('Error loading FTMS display config: $e');
      return null;
    }
  }
}
