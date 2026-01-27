import 'dart:async';
import 'dart:math';
import 'package:flutter_ftms/flutter_ftms.dart';
// ignore: implementation_imports
import 'package:flutter_ftms/src/ftms/flag.dart';
// ignore: implementation_imports
import 'package:flutter_ftms/src/ftms/parameter_name.dart';
import 'package:ftms/core/bloc/ftms_bloc.dart';
import 'package:ftms/core/utils/logger.dart';

/// Simulates a rowing machine FTMS device for demo mode.
/// Generates realistic rowing data that mimics real device behavior.
class SimulatedRowerDevice {
  Timer? _dataTimer;
  bool _isRunning = false;
  final Random _random = Random();
  
  // Simulated workout state
  int _elapsedSeconds = 0;
  double _totalDistance = 0;
  int _strokeCount = 0;
  double _totalCalories = 0;
  
  // Current values that change during simulation
  double _currentPace = 0.0; // 0 = idle/inactive
  double _currentPower = 0.0; // 0W = idle/inactive
  double _currentStrokeRate = 0.0; // 0 spm = idle/inactive
  int _currentHeartRate = 80; // resting heart rate
  
  // Target values for the simulation
  double _targetPace = 0.0; // Start idle
  double _targetPower = 0.0; // Start idle
  double _targetStrokeRate = 0.0; // Start idle
  int _targetResistanceLevel = 50;
  
  // Callbacks for device state changes
  final void Function(DeviceData)? onDataReceived;
  final void Function()? onConnected;
  final void Function()? onDisconnected;
  
  SimulatedRowerDevice({
    this.onDataReceived,
    this.onConnected,
    this.onDisconnected,
  });
  
  /// Whether the simulated device is currently connected and streaming data
  bool get isRunning => _isRunning;
  
  /// Current elapsed time in seconds
  int get elapsedSeconds => _elapsedSeconds;
  
  /// Current total distance in meters
  double get totalDistance => _totalDistance;
  
  /// Simulate connecting to the device
  Future<void> connect() async {
    logger.i('🎮 Simulated rower connecting...');
    
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    _isRunning = true;
    onConnected?.call();
    
    logger.i('🎮 Simulated rower connected');
    
    // Auto-start rowing immediately with moderate power to trigger session auto-start
    // Set target power BEFORE starting data generation so first data point reflects active state
    _targetPower = 120.0; // Start with 120W (moderate effort)
    logger.i('🎮 Simulated rower auto-starting workout - setting target power to 120W');
    
    // Start generating data every second (this will emit initial data with active power)
    _startDataGeneration();
  }
  
  /// Simulate disconnecting from the device
  Future<void> disconnect() async {
    logger.i('🎮 Simulated rower disconnecting...');
    
    _stopDataGeneration();
    _isRunning = false;
    _resetState();
    
    onDisconnected?.call();
    logger.i('🎮 Simulated rower disconnected');
  }
  
  /// Set target resistance level (0-100)
  void setResistanceLevel(int level) {
    _targetResistanceLevel = level.clamp(0, 100);
    
    // Adjust power and pace based on resistance
    // Higher resistance = higher power output, potentially slower pace
    _targetPower = 100 + (_targetResistanceLevel * 2.5);
    logger.d('🎮 Simulated rower resistance set to $level, target power: ${_targetPower.toStringAsFixed(0)}W');
  }
  
  /// Set target power in watts
  void setTargetPower(int power) {
    _targetPower = power.toDouble().clamp(50, 500);
    logger.d('🎮 Simulated rower target power set to $power W');
  }
  
  /// Simulate user starting to row
  void startRowing() {
    _isRunning = true;
    logger.i('🎮 Simulated rowing started');
  }
  
  /// Simulate user stopping rowing
  void stopRowing() {
    // Don't stop data generation, just reduce values
    _targetPower = 0;
    _targetStrokeRate = 0;
    _targetPace = 999; // Very slow pace when stopped
    logger.i('🎮 Simulated rowing stopped');
  }
  
  void _startDataGeneration() {
    _dataTimer?.cancel();
    _dataTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _generateDataPoint();
    });
    
    // Also emit initial data point immediately
    _generateDataPoint();
  }
  
  void _stopDataGeneration() {
    _dataTimer?.cancel();
    _dataTimer = null;
  }
  
  void _resetState() {
    _elapsedSeconds = 0;
    _totalDistance = 0;
    _strokeCount = 0;
    _totalCalories = 0;
    _currentPace = 0.0; // Start idle
    _currentPower = 0.0; // Start idle
    _currentStrokeRate = 0.0; // Start idle
    _currentHeartRate = 80; // Resting heart rate
  }
  
  void _generateDataPoint() {
    _elapsedSeconds++;
    
    // Smoothly adjust current values toward targets with some noise
    _updateCurrentValues();
    
    // Calculate derived values
    _updateDerivedValues();
    
    // Create and emit device data
    final deviceData = _createDeviceData();
    
    logger.i('🎮 Simulated data point ${ _elapsedSeconds}s: pace=$_currentPace, power=$_currentPower, heartRate=$_currentHeartRate');
    logger.i('🎮 Target values: targetPace=$_targetPace, targetPower=$_targetPower');
    
    // Get parameter values for debugging
    final params = deviceData.getDeviceDataParameterValues();
    logger.i('🎮 Device data parameters count: ${params.length}');
    for (final p in params) {
      logger.d('   - ${p.name.name}: ${p.value}');
    }
    
    // Send to FTMS bloc for consumption by the app
    logger.i('🎮 Adding data to ftmsBloc sink...');
    ftmsBloc.ftmsDeviceDataControllerSink.add(deviceData);
    logger.i('🎮 Data added to sink');
    
    // Also notify direct listeners
    onDataReceived?.call(deviceData);
  }
  
  void _updateCurrentValues() {
    // Smooth interpolation with noise
    const noiseFactor = 0.05; // 5% random variation
    
    // Update power with smooth transition
    _currentPower = _smoothTransition(_currentPower, _targetPower, 0.3);
    _currentPower += (_random.nextDouble() - 0.5) * _currentPower * noiseFactor;
    _currentPower = _currentPower.clamp(0, 500);
    
    // Update stroke rate
    _targetStrokeRate = _calculateTargetStrokeRate();
    _currentStrokeRate = _smoothTransition(_currentStrokeRate, _targetStrokeRate, 0.2);
    _currentStrokeRate += (_random.nextDouble() - 0.5) * 2;
    _currentStrokeRate = _currentStrokeRate.clamp(0, 40);
    
    // Update pace based on power (higher power = faster/lower pace)
    _targetPace = _calculateTargetPace();
    _currentPace = _smoothTransition(_currentPace, _targetPace, 0.3); // Slightly faster transition
    _currentPace += (_random.nextDouble() - 0.5) * 2; // Less noise
    
    // Clamp pace: 
    // - When idle (targetPace >= 300): allow pace to be 0 or very high
    // - When active (targetPace < 300): clamp to active range
    if (_targetPace >= 300) {
      _currentPace = _currentPace.clamp(0, 999); // Idle range
    } else {
      _currentPace = _currentPace.clamp(50, 250); // Active range (wider for safety)
    }
    
    // Update heart rate based on power output
    final targetHr = _calculateTargetHeartRate();
    _currentHeartRate = _smoothTransition(_currentHeartRate.toDouble(), targetHr.toDouble(), 0.1).round();
    _currentHeartRate += (_random.nextInt(3) - 1);
    _currentHeartRate = _currentHeartRate.clamp(60, 200);
    
    logger.d('🎮 Simulated data - Power: $_currentPower W, Pace: $_currentPace, HR: $_currentHeartRate bpm');
  }
  
  double _smoothTransition(double current, double target, double factor) {
    return current + (target - current) * factor;
  }
  
  double _calculateTargetStrokeRate() {
    // Higher power typically correlates with higher stroke rate
    // Range: 18-32 spm depending on power
    if (_targetPower <= 0) return 0;
    return 18 + (_targetPower / 500) * 14;
  }
  
  double _calculateTargetPace() {
    // Power to pace conversion (approximate)
    // 100W ≈ 2:20/500m, 200W ≈ 1:55/500m, 300W ≈ 1:40/500m
    if (_targetPower <= 0) return 999;
    
    // Simplified formula: pace = 300 - (power - 100) * 0.3
    final pace = 300 - (_targetPower - 100) * 0.2;
    return pace.clamp(90, 180); // 1:30 to 3:00 per 500m
  }
  
  int _calculateTargetHeartRate() {
    // Heart rate correlates with power/effort
    // Range: 100-180 bpm based on power
    if (_targetPower <= 0) return 80;
    return (100 + (_targetPower / 400) * 80).round().clamp(80, 180);
  }
  
  void _updateDerivedValues() {
    // Calculate distance from pace
    // pace is in seconds/500m, so speed in m/s = 500 / pace
    if (_currentPace > 0 && _currentPace < 999) {
      final speedMps = 500 / _currentPace;
      _totalDistance += speedMps; // Add distance for this second
    }
    
    // Update stroke count based on stroke rate
    if (_currentStrokeRate > 0) {
      _strokeCount = (_elapsedSeconds * _currentStrokeRate / 60).round();
    }
    
    // Approximate calorie calculation
    // ~0.1 calories per watt per minute
    _totalCalories += (_currentPower * 0.1 / 60);
  }
  
  DeviceData _createDeviceData() {
    // Create a simulated RowerData object using the library's API
    return SimulatedRowerData(
      elapsedTimeSeconds: _elapsedSeconds,
      totalDistanceMeters: _totalDistance.round(),
      instantaneousPace: _currentPace.round(),
      averagePace: _currentPace.round(),
      instantaneousPower: _currentPower.round(),
      averagePower: _currentPower.round(),
      strokeRate: _currentStrokeRate.round(),
      strokeCount: _strokeCount,
      totalEnergy: _totalCalories.round(),
      heartRate: _currentHeartRate,
      resistanceLevel: _targetResistanceLevel,
    );
  }
  
  void dispose() {
    _stopDataGeneration();
  }
}

/// Mock parameter name for simulated data
class _MockParameterName implements ParameterName {
  final String _name;
  _MockParameterName(this._name);
  
  @override
  String get name => _name;
}

/// Mock parameter value for simulated data
class _MockParameterValue implements DeviceDataParameterValue {
  final ParameterName _name;
  final int _value;
  
  _MockParameterValue(String name, this._value) : _name = _MockParameterName(name);
  
  @override
  ParameterName get name => _name;
  
  @override
  int get value => _value;
  
  @override
  bool get signed => false;
  
  @override
  DeviceDataParameterValue toDeviceDataParameterValue(int value) {
    return _MockParameterValue(_name.name, value);
  }
  
  @override
  Flag? get flag => null;
  
  @override
  num get factor => 1;
  
  @override
  int get size => 2;
  
  @override
  String get unit => '';
}

/// Simulated rower data that implements DeviceData interface
class SimulatedRowerData extends DeviceData {
  final int elapsedTimeSeconds;
  final int totalDistanceMeters;
  final int instantaneousPace;
  final int averagePace;
  final int instantaneousPower;
  final int averagePower;
  final int strokeRate;
  final int strokeCount;
  final int totalEnergy;
  final int heartRate;
  final int resistanceLevel;
  
  SimulatedRowerData({
    required this.elapsedTimeSeconds,
    required this.totalDistanceMeters,
    required this.instantaneousPace,
    required this.averagePace,
    required this.instantaneousPower,
    required this.averagePower,
    required this.strokeRate,
    required this.strokeCount,
    required this.totalEnergy,
    required this.heartRate,
    required this.resistanceLevel,
  }) : super([0, 0, 0, 0]); // Pass dummy raw data
  
  @override
  DeviceDataType get deviceDataType => DeviceDataType.rower;
  
  @override
  List<Flag> get allDeviceDataFlags => [];
  
  @override
  List<DeviceDataParameter> get allDeviceDataParameters => [];
  
  @override
  List<DeviceDataParameterValue> getDeviceDataParameterValues() {
    return [
      _MockParameterValue('Stroke Rate', strokeRate),
      _MockParameterValue('Stroke Count', strokeCount),
      _MockParameterValue('Total Distance', totalDistanceMeters),
      _MockParameterValue('Instantaneous Pace', instantaneousPace),
      _MockParameterValue('Average Pace', averagePace),
      _MockParameterValue('Instantaneous Power', instantaneousPower),
      _MockParameterValue('Average Power', averagePower),
      _MockParameterValue('Resistance Level', resistanceLevel),
      _MockParameterValue('Total Energy', totalEnergy),
      _MockParameterValue('Heart Rate', heartRate),
      _MockParameterValue('Elapsed Time', elapsedTimeSeconds),
    ];
  }
}
