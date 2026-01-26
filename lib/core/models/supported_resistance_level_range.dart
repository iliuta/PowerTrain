/// Model for FTMS Supported Resistance Level Range characteristic
/// UUID: 2AD6
/// Reference: Bluetooth FTMS Specification
/// https://www.bluetooth.org/DocMan/handlers/DownloadDoc.ashx?doc_id=423422
class SupportedResistanceLevelRange {
  /// Minimum Resistance Level in ohms
  final int minResistanceLevel;

  /// Maximum Resistance Level in ohms
  final int maxResistanceLevel;

  /// Minimum Increment in ohms
  final int minIncrement;

  SupportedResistanceLevelRange({
    required this.minResistanceLevel,
    required this.maxResistanceLevel,
    required this.minIncrement,
  });
  
  /// Returns the minimum control value (in ohms)
  int get minControlValue => minResistanceLevel;
  
  /// Returns the maximum control value (in ohms)
  int get maxControlValue => maxResistanceLevel;
  
  /// Returns the control increment step (in ohms)
  int get controlIncrement => minIncrement;

  /// Returns the maximum user input value (1-based range)
  int get maxUserInput => minResistanceLevel == 0
      ? ((maxResistanceLevel - minResistanceLevel) ~/ minIncrement)
      : ((maxResistanceLevel - minResistanceLevel) ~/ minIncrement) + 1;

  /// Converts user input (1 to maxUserInput) to machine resistance level
  int convertUserInputToMachine(int userInput) {
    if (userInput < 1 || userInput > maxUserInput) {
      throw ArgumentError('User input must be between 1 and $maxUserInput');
    }
    if (minResistanceLevel == 0) {
      return minResistanceLevel + userInput * minIncrement;
    } else {
      return minResistanceLevel + (userInput - 1) * minIncrement;
    }
  }

  /// Converts machine resistance level to user input value
  int convertMachineToUserInput(int machineValue) {
    if (machineValue < minResistanceLevel || machineValue > maxResistanceLevel) {
      throw ArgumentError('Machine value must be between $minResistanceLevel and $maxResistanceLevel');
    }
    if ((machineValue - minResistanceLevel) % minIncrement != 0) {
      throw ArgumentError('Machine value $machineValue is not a valid step');
    }
    if (minResistanceLevel == 0) {
      return (machineValue - minResistanceLevel) ~/ minIncrement;
    } else {
      return ((machineValue - minResistanceLevel) ~/ minIncrement) + 1;
    }
  }

  /// Parse the characteristic value (6 bytes minimum)
  /// Format (Supported Resistance Level Range characteristic):
  /// Bytes 0-1: Minimum Resistance Level (sint16)
  /// Bytes 2-3: Maximum Resistance Level (sint16)
  /// Bytes 4-5: Minimum Increment (uint16)
  factory SupportedResistanceLevelRange.fromBytes(List<int> data) {
    if (data.length < 6) {
      throw ArgumentError('Expected at least 6 bytes, got ${data.length}');
    }

    // Parse sint16 for min resistance level
    int minRaw = (data[1] << 8) | data[0];
    if (minRaw & 0x8000 != 0) {
      minRaw = minRaw - 0x10000; // Convert to signed
    }
    final minResistanceLevel = minRaw;

    // Parse sint16 for max resistance level
    int maxRaw = (data[3] << 8) | data[2];
    if (maxRaw & 0x8000 != 0) {
      maxRaw = maxRaw - 0x10000; // Convert to signed
    }
    final maxResistanceLevel = maxRaw;

    // Parse uint16 for min increment
    final minIncrement = ((data[5] << 8) | data[4]).toUnsigned(16);

    return SupportedResistanceLevelRange(
      minResistanceLevel: minResistanceLevel,
      maxResistanceLevel: maxResistanceLevel,
      minIncrement: minIncrement,
    );
  }

  @override
  String toString() =>
      'SupportedResistanceLevelRange(min: $minResistanceLevel Ω, max: $maxResistanceLevel Ω, increment: $minIncrement Ω)';

  /// Default resistance range used for offline editing when the machine is not connected.
  /// Range: 10-150 with increment of 10 (user inputs 1-15, stored as 10-150).
  static SupportedResistanceLevelRange get defaultOfflineRange =>
      SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

  /// Converts a resistance value stored using the default offline range
  /// to the equivalent value for this (actual machine) range.
  /// 
  /// The conversion maps the relative position (percentage) of the stored value
  /// within the default range to the same relative position in this range.
  /// 
  /// For example, if stored value is 80 in default range (10-150), that's at ~50%,
  /// so it maps to ~50% of this range.
  int convertFromDefaultRange(int storedValue) {
    final defaultRange = SupportedResistanceLevelRange.defaultOfflineRange;
    
    // Calculate the relative position (0.0 to 1.0) of the stored value in the default range
    final relativePosition = (storedValue - defaultRange.minResistanceLevel) /
        (defaultRange.maxResistanceLevel - defaultRange.minResistanceLevel);
    
    // Map to this range
    final rawValue = minResistanceLevel +
        (relativePosition * (maxResistanceLevel - minResistanceLevel));
    
    // Round to the nearest valid step
    final steps = ((rawValue - minResistanceLevel) / minIncrement).round();
    final clampedSteps = steps.clamp(0, (maxResistanceLevel - minResistanceLevel) ~/ minIncrement);
    
    return minResistanceLevel + (clampedSteps * minIncrement);
  }

  /// Converts a resistance value from this (actual machine) range
  /// to the equivalent value in the default offline range for storage.
  /// 
  /// The conversion maps the relative position (percentage) of the value
  /// within this range to the same relative position in the default range.
  /// 
  /// For example, if the actual machine has range 0-100 and value is 50,
  /// that's at 50%, so it maps to 50% of default range (10-150) = 80.
  int convertToDefaultRange(int machineValue) {
    final defaultRange = SupportedResistanceLevelRange.defaultOfflineRange;
    
    // Calculate the relative position (0.0 to 1.0) of the value in this range
    final relativePosition = (machineValue - minResistanceLevel) /
        (maxResistanceLevel - minResistanceLevel);
    
    // Map to default range
    final rawValue = defaultRange.minResistanceLevel +
        (relativePosition * (defaultRange.maxResistanceLevel - defaultRange.minResistanceLevel));
    
    // Round to the nearest valid step in default range
    final steps = ((rawValue - defaultRange.minResistanceLevel) / defaultRange.minIncrement).round();
    final clampedSteps = steps.clamp(0, (defaultRange.maxResistanceLevel - defaultRange.minResistanceLevel) ~/ defaultRange.minIncrement);
    
    return defaultRange.minResistanceLevel + (clampedSteps * defaultRange.minIncrement);
  }
}
