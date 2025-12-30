
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/analytics/analytics_service.dart';
import 'package:ftms/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/scan/scan_page.dart';
import 'features/scan/scan_widgets.dart';
import 'features/common/burger_menu.dart';
import 'core/services/devices/bt_device.dart';
import 'core/services/devices/bt_device_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    AnalyticsService().initialize();
    logger.i('🔥 Firebase initialized successfully');
  } catch (e) {
    logger.e('🔥 Failed to initialize Firebase: $e');
  }
  
  // Note: Edge-to-edge is automatically enabled on Android 15+ (Flutter 3.27+)
  // We do NOT call SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)
  // to avoid triggering deprecated Android APIs (setStatusBarColor, etc.)
  // See: https://docs.flutter.dev/release/breaking-changes/default-systemuimode-edge-to-edge
  
  // Set log level for production
  FlutterBluePlus.setLogLevel(LogLevel.warning);
  
  // Initialize device navigation callbacks to avoid circular dependencies
  initializeDeviceNavigation();
  
  // Initialize the new device management system
  logger.i('🚀 Initializing BTDevice system...');
  await SupportedBTDeviceManager().initialize();
  
  logger.i('🚀 Looking for already connected devices...');
  await SupportedBTDeviceManager().identifyAndConnectExistingDevices();
  
  logger.i('🚀 Starting app with ${SupportedBTDeviceManager().allConnectedDevices.length} connected devices');

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    // Configure edge-to-edge display for Android 15+
    // System UI overlay style is not set to avoid deprecated APIs
    
    return MaterialApp(
      title: 'Fitness machines',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const FlutterFTMSApp(),
    );
  }
}

class FlutterFTMSApp extends StatefulWidget {
  const FlutterFTMSApp({super.key});

  @override
  State<FlutterFTMSApp> createState() => _FlutterFTMSAppState();
}

class _FlutterFTMSAppState extends State<FlutterFTMSApp> {
  BluetoothDevice? _connectedFtmsDevice;

  @override
  void initState() {
    super.initState();
    
    // Listen to connected devices changes
    SupportedBTDeviceManager().connectedDevicesStream.listen((devices) {
      _updateConnectedFtmsDevice(devices);
    });

    // Get initial connected device if any
    _updateConnectedFtmsDevice(SupportedBTDeviceManager().allConnectedDevices);
  }

  void _updateConnectedFtmsDevice(List<BTDevice> devices) {
    // Find the first FTMS device
    final ftmsDevice = SupportedBTDeviceManager().getConnectedFtmsDevice();
    
    final newFtmsDevice = ftmsDevice?.connectedDevice;
    if (mounted && _connectedFtmsDevice != newFtmsDevice) {
      setState(() {
        _connectedFtmsDevice = newFtmsDevice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fitness machines"),
        titleSpacing: 0, // Reduce spacing between leading and title
        leading: BurgerMenu(connectedDevice: _connectedFtmsDevice),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.coffee,
                color: Colors.brown,
                size: 18,
              ),
              label: const Text(
                'Buy me a coffee',
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () async {
                final Uri url = Uri.parse('https://coff.ee/iliuta');
                try {
                  final bool launched = await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  );
                  
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open the coffee link. Please visit https://coff.ee/iliuta manually.'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening coffee link: $e'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: const ScanPage(),
    );
  }
}

