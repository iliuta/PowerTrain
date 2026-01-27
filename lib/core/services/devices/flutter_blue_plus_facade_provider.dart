import 'dart:async';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade_demo_impl.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade_impl.dart';
import 'package:ftms/core/services/user_settings_service.dart';

/// Global singleton for accessing the facade
/// Can be switched between real and demo mode based on user settings
class FlutterBluePlusFacadeProvider {
  FlutterBluePlusFacadeProvider._();

  static final FlutterBluePlusFacadeProvider _instance =
  FlutterBluePlusFacadeProvider._();

  factory FlutterBluePlusFacadeProvider() => _instance;

  final FlutterBluePlusFacadeImpl _realFacade = FlutterBluePlusFacadeImpl();
  final DemoFlutterBluePlusFacade _demoFacade = DemoFlutterBluePlusFacade();
  
  /// Stream controller to notify when facade mode changes
  final StreamController<void> _modeChangeController = StreamController<void>.broadcast();
  
  /// Stream that emits when the facade mode changes
  Stream<void> get onModeChanged => _modeChangeController.stream;

  /// Get the current facade (real or demo based on user settings)
  /// Uses cached settings to determine the mode
  FlutterBluePlusFacade get facade {
    final settings = UserSettingsService.instance.getCachedSettings();
    final isDemoMode = settings?.demoModeEnabled ?? false;
    return isDemoMode ? _demoFacade : _realFacade;
  }

  /// Set demo mode and notify listeners
  void setDemoMode(bool enabled) {
    if (enabled) {
      enableDemoMode();
    } else {
      disableDemoMode();
    }
  }

  /// Enable demo mode and notify listeners
  void enableDemoMode() {
    _modeChangeController.add(null);
  }

  /// Disable demo mode and notify listeners
  void disableDemoMode() {
    _modeChangeController.add(null);
  }

  /// Get the demo facade for direct access to demo devices
  DemoFlutterBluePlusFacade get demoFacade => _demoFacade;
  
  /// Dispose the controller
  void dispose() {
    _modeChangeController.close();
  }
}