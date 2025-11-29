/// Enum for Bluetooth device service types
/// Represents the different categories of Bluetooth devices supported by the app
enum BTDeviceServiceType {
  hrm('HRM'),
  cadence('Cadence'),
  ftms('FTMS');

  final String name;
  const BTDeviceServiceType(this.name);

  /// Create from string name
  static BTDeviceServiceType fromString(String name) {
    switch (name.toUpperCase()) {
      case 'HRM':
        return BTDeviceServiceType.hrm;
      case 'CADENCE':
        return BTDeviceServiceType.cadence;
      case 'FTMS':
        return BTDeviceServiceType.ftms;
      default:
        throw ArgumentError('Unknown device service type: $name');
    }
  }

  /// Get all supported device service types
  static List<BTDeviceServiceType> get all => BTDeviceServiceType.values;
}
