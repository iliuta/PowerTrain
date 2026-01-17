// This file was moved from lib/scan_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade_provider.dart';
import '../../core/utils/logger.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../core/services/strava/strava_service.dart';
import '../../core/services/devices/bt_device.dart';
import '../../core/services/devices/bt_device_manager.dart';
import '../../core/services/devices/bt_scan_service.dart';
import '../../core/services/devices/flutter_blue_plus_facade.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:in_app_review/in_app_review.dart';
import '../../core/services/in_app_review_service.dart';
import '../../l10n/app_localizations.dart';

import 'scan_widgets.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Helper to detect test environment
  bool get isInTest => Platform.environment['FLUTTER_TEST'] == 'true';
  final StravaService _stravaService = StravaService();
  final BluetoothScanService _bluetoothScanService = BluetoothScanService();
  final InAppReviewService _reviewService = InAppReviewService();
  bool _isConnectingStrava = false;
  String? _stravaStatus;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  bool _hasStartedScan = false;
  
  /// Get the FlutterBluePlus facade (real or demo)
  FlutterBluePlusFacade get _bluetoothFacade => FlutterBluePlusFacadeProvider().facade;
  bool _showReviewBanner = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(
      screenName: 'device_scan',
      screenClass: 'ScanPage',
    );
    _printBluetoothState();
    _checkStravaStatus();
    _checkAndRequestReview();
    _listenToAdapterState();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkStravaStatus() async {
    final status = await _stravaService.getAuthStatus();
    setState(() {
      if (status != null) {
        _stravaStatus = AppLocalizations.of(
          context,
        )!.connectedAsAthlete(status['athleteName']);
      } else {
        _stravaStatus = null;
      }
    });
  }

  Future<void> _checkAndRequestReview() async {
    //await _reviewService.resetAll();
    await _reviewService.incrementUsageCount();
    if (await _reviewService.shouldShowReview()) {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        setState(() {
          _showReviewBanner = true;
        });
      }
    }
  }

  void _dismissReviewBanner() async {
    await _reviewService.handleReviewDismissal();
    setState(() {
      _showReviewBanner = false;
    });
  }

  void _requestReview() async {
    final InAppReview inAppReview = InAppReview.instance;
    await inAppReview.requestReview();

    await _reviewService.handleReviewCompleted();
    _dismissReviewBanner();
  }

  Future<void> _handleStravaConnection() async {
    if (_isConnectingStrava) return;

    setState(() {
      _isConnectingStrava = true;
    });

    try {
      // Show initial feedback with detailed instructions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.openingStravaAuth),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.signInStravaPopup,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      final success = await _stravaService.authenticate(context: context);

      if (success) {
        await _checkStravaStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.stravaConnected),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.stravaAuthIncomplete),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.stravaAuthRetry,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      logger.e('Error connecting to Strava: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.stravaError(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isConnectingStrava = false;
      });
    }
  }

  void _printBluetoothState() {
    // Listen to the adapter state stream (logging removed for production)
    _bluetoothFacade.adapterState.listen((state) {
      logger.i('Bluetooth adapter state: [0m${state.toString()}');
    });
    // Also print the last known state immediately
    logger.i(
      'Bluetooth adapter state (now): ${_bluetoothFacade.adapterStateNow.toString()}',
    );

    // Log platform information
    logger.i('Platform: ${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      logger.i('Running on Android - will request runtime permissions');
    }
  }

  void _listenToAdapterState() {
    _adapterStateSubscription = _bluetoothFacade.adapterState.listen((state) {
      logger.i('Bluetooth adapter state changed: $state');
      if (state == BluetoothAdapterState.on && !_hasStartedScan && mounted) {
        _hasStartedScan = true;
        _startScan();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if adapter is already on and start scanning if not already done
    if (_bluetoothFacade.adapterStateNow == BluetoothAdapterState.on &&
        !_hasStartedScan) {
      _hasStartedScan = true;
      _startScan();
    }
  }

  Future<void> _startScan() async {
    // Capture ScaffoldMessenger before the async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await _bluetoothScanService.startScan();

    // Handle UI feedback in the UI layer based on specific error
    if (result != BTScanResult.success && mounted) {
      switch (result) {
        case BTScanResult.permissionDenied:
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.bluetoothPermissionsRequired,
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async => await ph.openAppSettings(),
              ),
            ),
          );
          break;

        case BTScanResult.scanError:
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.bluetoothScanFailed),
              backgroundColor: Colors.orange,
            ),
          );
          break;

        default:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false, // AppBar handles top insets
      bottom: false, // Allow content to extend to bottom for overlay buttons
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40.0),
        // Add bottom padding for overlay buttons
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // If the screen is narrow, stack buttons vertically
                    if (constraints.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              AppLocalizations.of(context)!.scanForDevices,
                            ),
                            onPressed: _startScan,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: _isConnectingStrava
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _stravaStatus != null
                                        ? Icons.check_circle
                                        : Icons.link,
                                  ),
                            label: Text(
                              _stravaStatus != null
                                  ? AppLocalizations.of(
                                      context,
                                    )!.connectedToStrava
                                  : AppLocalizations.of(
                                      context,
                                    )!.connectToStrava,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _stravaStatus != null
                                  ? Colors.green
                                  : null,
                              foregroundColor: _stravaStatus != null
                                  ? Colors.white
                                  : null,
                            ),
                            onPressed: _isConnectingStrava
                                ? null
                                : _handleStravaConnection,
                          ),
                        ],
                      );
                    } else {
                      // For wider screens, keep horizontal layout
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                AppLocalizations.of(context)!.scanForDevices,
                              ),
                              onPressed: _startScan,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: ElevatedButton.icon(
                              icon: _isConnectingStrava
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _stravaStatus != null
                                          ? Icons.check_circle
                                          : Icons.link,
                                    ),
                              label: Text(
                                _stravaStatus != null
                                    ? AppLocalizations.of(
                                        context,
                                      )!.connectedToStrava
                                    : AppLocalizations.of(
                                        context,
                                      )!.connectToStrava,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _stravaStatus != null
                                    ? Colors.green
                                    : null,
                                foregroundColor: _stravaStatus != null
                                    ? Colors.white
                                    : null,
                              ),
                              onPressed: _isConnectingStrava
                                  ? null
                                  : _handleStravaConnection,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
              if (_showReviewBanner)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.enjoyingAppReviewPrompt,
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                        TextButton(
                          onPressed: _requestReview,
                          child: Text(AppLocalizations.of(context)!.rateNow),
                        ),
                        IconButton(
                          onPressed: _dismissReviewBanner,
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_stravaStatus != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _stravaStatus!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          // Capture the ScaffoldMessengerState before async operations
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final disconnectedMessage = AppLocalizations.of(
                            context,
                          )!.disconnectedFromStrava;
                          await _stravaService.signOut();
                          await _checkStravaStatus();
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text(disconnectedMessage)),
                            );
                          }
                        },
                        child: const Icon(
                          Icons.logout,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              // HRM Status Widget
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: _bluetoothFacade.scanResults,
                  initialData: const [],
                  builder: (c, scanSnapshot) {
                    return StreamBuilder<List<BTDevice>>(
                      stream: SupportedBTDeviceManager().connectedDevicesStream,
                      initialData:
                          SupportedBTDeviceManager().allConnectedDevices,
                      builder: (context, connectedSnapshot) {
                        final scanResults = (scanSnapshot.data ?? [])
                            .where(
                              (element) =>
                                  element.device.platformName.isNotEmpty ||
                                  element.advertisementData.advName.isNotEmpty,
                            )
                            .toList();

                        return RefreshIndicator(
                          onRefresh: _startScan,
                          child: scanResultsToWidget(scanResults, context),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
