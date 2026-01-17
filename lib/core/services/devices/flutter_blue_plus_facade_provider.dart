import 'package:ftms/core/services/devices/flutter_blue_plus_facade.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade_demo_impl.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade_impl.dart';

/// Global singleton for accessing the facade
/// Can be switched between real and demo mode
class FlutterBluePlusFacadeProvider {
  FlutterBluePlusFacadeProvider._();

  static final FlutterBluePlusFacadeProvider _instance =
  FlutterBluePlusFacadeProvider._();

  factory FlutterBluePlusFacadeProvider() => _instance;

  bool _demoModeEnabled = false;
  final FlutterBluePlusFacadeImpl _realFacade = FlutterBluePlusFacadeImpl();
  final DemoFlutterBluePlusFacade _demoFacade = DemoFlutterBluePlusFacade();

  /// Get the current facade (real or demo based on mode)
  FlutterBluePlusFacade get facade =>
      _demoModeEnabled ? _demoFacade : _realFacade;

  /// Check if demo mode is enabled
  bool get isDemoMode => _demoModeEnabled;

  /// Enable demo mode
  void enableDemoMode() {
    _demoModeEnabled = true;
  }

  /// Disable demo mode
  void disableDemoMode() {
    _demoModeEnabled = false;
  }

  /// Toggle demo mode
  void toggleDemoMode() {
    _demoModeEnabled = !_demoModeEnabled;
  }

  /// Get the demo facade for direct access to demo devices
  DemoFlutterBluePlusFacade get demoFacade => _demoFacade;
}