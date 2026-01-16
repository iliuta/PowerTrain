import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';

/// Service for managing demo mode state.
/// Demo mode allows users to experience the app's features without real Bluetooth hardware.
/// This is particularly useful for App Store review and demonstration purposes.
class DemoModeService {
  static DemoModeService? _instance;
  static const String _demoModeKey = 'demo_mode_enabled';
  
  bool _isDemoModeEnabled = false;
  final StreamController<bool> _demoModeController = StreamController<bool>.broadcast();
  
  DemoModeService._();
  
  factory DemoModeService() {
    return _instance ??= DemoModeService._();
  }
  
  /// Stream of demo mode state changes
  Stream<bool> get demoModeStream => _demoModeController.stream;
  
  /// Whether demo mode is currently enabled
  bool get isDemoModeEnabled => _isDemoModeEnabled;
  
  /// Initialize the service and load saved state
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDemoModeEnabled = prefs.getBool(_demoModeKey) ?? false;
      _demoModeController.add(_isDemoModeEnabled);
      logger.i('🎮 Demo mode initialized: $_isDemoModeEnabled');
    } catch (e) {
      logger.e('Failed to initialize demo mode: $e');
    }
  }
  
  /// Enable or disable demo mode
  Future<void> setDemoMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_demoModeKey, enabled);
      _isDemoModeEnabled = enabled;
      _demoModeController.add(enabled);
      logger.i('🎮 Demo mode ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      logger.e('Failed to set demo mode: $e');
    }
  }
  
  /// Toggle demo mode on/off
  Future<void> toggleDemoMode() async {
    await setDemoMode(!_isDemoModeEnabled);
  }
  
  /// Reset singleton for testing
  static void resetInstance() {
    _instance = null;
  }
  
  void dispose() {
    _demoModeController.close();
  }
}
