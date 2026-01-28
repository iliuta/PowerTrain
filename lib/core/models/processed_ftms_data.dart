import 'package:flutter_ftms/flutter_ftms.dart' show DeviceData;
import 'device_types.dart';
import 'live_data_field_value.dart';

/// Represents processed FTMS data ready for UI consumption.
/// 
/// This class wraps the processed data map (with averaging, HRM override, etc.)
/// along with the device type, eliminating the need for consumers to process
/// raw DeviceData themselves.
class ProcessedFtmsData {
  /// The device type (indoor bike, rower, etc.)
  final DeviceType deviceType;
  
  /// The processed parameter values map, with averaging and sensor overrides applied
  final Map<String, LiveDataFieldValue> paramValueMap;
  
  /// Optional raw device data features for debugging/features display
  /// Keys are DeviceDataFlag instances from flutter_ftms
  final Map<Object, bool>? features;

  const ProcessedFtmsData({
    required this.deviceType,
    required this.paramValueMap,
    this.features,
  });
  
  /// Factory to create from raw DeviceData and processed param map
  factory ProcessedFtmsData.fromDeviceData(
    DeviceData deviceData,
    Map<String, LiveDataFieldValue> processedParamValueMap,
  ) {
    return ProcessedFtmsData(
      deviceType: DeviceType.fromFtms(deviceData.deviceDataType),
      paramValueMap: processedParamValueMap,
      features: deviceData.getDeviceDataFeatures(),
    );
  }
}
