import 'package:flutter_ftms/flutter_ftms.dart';

/// add enum with device types
///
enum DeviceType {
  indoorBike,
  rower;

  static DeviceType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'devicedatatype.indoorbike':
      case 'devicetype.indoorbike':
      case 'indoorbike':
        return DeviceType.indoorBike;
      case 'devicedatatype.rower':
      case 'devicetype.rower':
      case 'rower':
        return DeviceType.rower;
      default:
        throw ArgumentError('Unknown device type: $type');
    }
  }

  static DeviceType fromFtms(DeviceDataType type) {
    switch (type) {
      case DeviceDataType.indoorBike:
        return DeviceType.indoorBike;
      case DeviceDataType.rower:
        return DeviceType.rower;
      default:
        throw ArgumentError('Unknown device data type: $type');
    }
  }

}