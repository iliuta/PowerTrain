/// Data models for Zwift trainer protocol messages.
/// 
/// Based on reverse-engineered protocol from:
/// https://www.makinolo.com/blog/2024/10/20/zwift-trainer-protocol/
library;

/// Riding Data from trainer (message 0x03)
/// 
/// Periodic notification received from trainer containing current riding metrics
class ZwiftRidingData {
  final int? power;           // Watts
  final int? cadence;         // RPM
  final double? speedKmh;     // km/h (derived from speedX100)
  final int? speedX100;       // Speed * 100
  final int? heartRate;       // BPM
  final int? unknown1;        // Unknown field (observed: 0, 2864, 4060, 4636, 6803)
  final int? unknown2;        // Unknown field (observed: constant ~25714)
  final DateTime timestamp;
  
  ZwiftRidingData({
    this.power,
    this.cadence,
    this.speedKmh,
    this.speedX100,
    this.heartRate,
    this.unknown1,
    this.unknown2,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory ZwiftRidingData.fromProtobuf(Map<String, dynamic> data) {
    return ZwiftRidingData(
      power: data['power'] as int?,
      cadence: data['cadence'] as int?,
      speedKmh: data['speedKmh'] as double?,
      speedX100: data['speedX100'] as int?,
      heartRate: data['heartRate'] as int?,
      unknown1: data['unknown1'] as int?,
      unknown2: data['unknown2'] as int?,
    );
  }
  
  @override
  String toString() {
    final parts = <String>[];
    if (power != null) parts.add('Power: $power W');
    if (cadence != null) parts.add('Cadence: $cadence RPM');
    if (speedKmh != null) parts.add('Speed: ${speedKmh!.toStringAsFixed(1)} km/h');
    if (heartRate != null) parts.add('HR: $heartRate BPM');
    return 'RidingData(${parts.join(', ')})';
  }
}

/// Simulation parameters from Trainer Control message (0x04, field 4)
class ZwiftSimulationParam {
  final double? windMps;         // Wind speed in m/s (negative = tailwind)
  final int? windX100;
  final double? inclinePercent;  // Grade percentage
  final int? inclineX100;
  final double? cwa;             // Aerodynamic coefficient CW*a
  final int? cwaX10000;
  final double? crr;             // Rolling resistance coefficient
  final int? crrX100000;
  
  ZwiftSimulationParam({
    this.windMps,
    this.windX100,
    this.inclinePercent,
    this.inclineX100,
    this.cwa,
    this.cwaX10000,
    this.crr,
    this.crrX100000,
  });
  
  factory ZwiftSimulationParam.fromProtobuf(Map<String, dynamic> data) {
    return ZwiftSimulationParam(
      windMps: data['windMps'] as double?,
      windX100: data['windX100'] as int?,
      inclinePercent: data['inclinePercent'] as double?,
      inclineX100: data['inclineX100'] as int?,
      cwa: data['cwa'] as double?,
      cwaX10000: data['cwaX10000'] as int?,
      crr: data['crr'] as double?,
      crrX100000: data['crrX100000'] as int?,
    );
  }
  
  @override
  String toString() {
    final parts = <String>[];
    if (inclinePercent != null) parts.add('Grade: ${inclinePercent!.toStringAsFixed(2)}%');
    if (windMps != null) parts.add('Wind: ${windMps!.toStringAsFixed(1)} m/s');
    if (cwa != null) parts.add('CWa: ${cwa!.toStringAsFixed(4)}');
    if (crr != null) parts.add('Crr: ${crr!.toStringAsFixed(5)}');
    return 'Simulation(${parts.join(', ')})';
  }
}

/// Physical parameters from Trainer Control message (0x04, field 5)
class ZwiftPhysicalParam {
  final double? gearRatio;
  final int? gearRatioX10000;
  final double? bikeWeightKg;
  final int? bikeWeightX100;
  final double? riderWeightKg;
  final int? riderWeightX100;
  
  ZwiftPhysicalParam({
    this.gearRatio,
    this.gearRatioX10000,
    this.bikeWeightKg,
    this.bikeWeightX100,
    this.riderWeightKg,
    this.riderWeightX100,
  });
  
  factory ZwiftPhysicalParam.fromProtobuf(Map<String, dynamic> data) {
    return ZwiftPhysicalParam(
      gearRatio: data['gearRatio'] as double?,
      gearRatioX10000: data['gearRatioX10000'] as int?,
      bikeWeightKg: data['bikeWeightKg'] as double?,
      bikeWeightX100: data['bikeWeightX100'] as int?,
      riderWeightKg: data['riderWeightKg'] as double?,
      riderWeightX100: data['riderWeightX100'] as int?,
    );
  }
  
  @override
  String toString() {
    final parts = <String>[];
    if (bikeWeightKg != null) parts.add('Bike: ${bikeWeightKg!.toStringAsFixed(1)} kg');
    if (riderWeightKg != null) parts.add('Rider: ${riderWeightKg!.toStringAsFixed(1)} kg');
    if (gearRatio != null) parts.add('Gear: ${gearRatio!.toStringAsFixed(2)}');
    return 'Physical(${parts.join(', ')})';
  }
}

/// Trainer Control message (0x04)
/// 
/// Command sent to trainer or response/acknowledgment from trainer
class ZwiftTrainerControl {
  final int? resistancePercent;      // Field 1 (likely, not confirmed)
  final int? powerTarget;            // Field 3 - ERG mode target
  final ZwiftSimulationParam? simulation;  // Field 4 - Simulation mode params
  final ZwiftPhysicalParam? physical;      // Field 5 - Bike/rider params
  final DateTime timestamp;
  
  ZwiftTrainerControl({
    this.resistancePercent,
    this.powerTarget,
    this.simulation,
    this.physical,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory ZwiftTrainerControl.fromProtobuf(Map<String, dynamic> data) {
    return ZwiftTrainerControl(
      resistancePercent: data['resistancePercent'] as int?,
      powerTarget: data['powerTarget'] as int?,
      simulation: data['simulation'] != null 
          ? ZwiftSimulationParam.fromProtobuf(data['simulation'] as Map<String, dynamic>)
          : null,
      physical: data['physical'] != null
          ? ZwiftPhysicalParam.fromProtobuf(data['physical'] as Map<String, dynamic>)
          : null,
    );
  }
  
  @override
  String toString() {
    final parts = <String>[];
    if (powerTarget != null) parts.add('Target: ${powerTarget}W');
    if (resistancePercent != null) parts.add('Resistance: $resistancePercent%');
    if (simulation != null) parts.add(simulation.toString());
    if (physical != null) parts.add(physical.toString());
    return 'TrainerControl(${parts.join(', ')})';
  }
}

/// Combined trainer status
/// 
/// Aggregates both riding data and current control settings
class ZwiftTrainerStatus {
  final ZwiftRidingData? ridingData;
  final ZwiftTrainerControl? control;
  final DateTime lastUpdate;
  
  ZwiftTrainerStatus({
    this.ridingData,
    this.control,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();
  
  ZwiftTrainerStatus copyWith({
    ZwiftRidingData? ridingData,
    ZwiftTrainerControl? control,
  }) {
    return ZwiftTrainerStatus(
      ridingData: ridingData ?? this.ridingData,
      control: control ?? this.control,
    );
  }
}
