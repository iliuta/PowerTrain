import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mockito/mockito.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/features/ftms/ftms_session_selector_tab.dart';
import 'package:ftms/features/ftms/models/session_selector_state.dart';
import 'package:ftms/features/ftms/services/session_selector_service.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Mock classes
class MockBluetoothDevice extends Mock implements BluetoothDevice {
  @override
  Future<List<BluetoothService>> discoverServices({
    bool subscribeToServicesChanged = true,
    int timeout = 15,
  }) async {
    return <BluetoothService>[];
  }

  @override
  DeviceIdentifier get remoteId => const DeviceIdentifier('00:00:00:00:00:00');

  @override
  String get platformName => 'Mock Rowing Machine';
}

/// A mock service that allows controlling state for testing
class MockSessionSelectorService extends SessionSelectorService {
  SessionSelectorState _testState;
  final List<String> methodCalls = [];

  MockSessionSelectorService({
    required super.ftmsDevice,
    SessionSelectorState? initialState,
  })  : _testState = initialState ?? const SessionSelectorState();

  void _notifyTestListeners() {
    for (final listener in listeners) {
      listener(_testState);
    }
  }

  List<void Function(SessionSelectorState)> get listeners => super.testListeners;

  @override
  Future<void> initialize() async {
    methodCalls.add('initialize');
    // Don't actually initialize - just notify with test state
    _notifyTestListeners();
  }

  @override
  void dispose() {
    methodCalls.add('dispose');
  }

  void setTestState(SessionSelectorState state) {
    _testState = state;
    _notifyTestListeners();
  }

  @override
  void toggleFreeRideExpanded() {
    methodCalls.add('toggleFreeRideExpanded');
    _testState = _testState.copyWith(
      expansionState: _testState.expansionState.copyWith(
        isFreeRideExpanded: !_testState.expansionState.isFreeRideExpanded,
      ),
    );
    _notifyTestListeners();
  }

  @override
  void toggleTrainingSessionExpanded() {
    methodCalls.add('toggleTrainingSessionExpanded');
    _testState = _testState.copyWith(
      expansionState: _testState.expansionState.copyWith(
        isTrainingSessionExpanded: !_testState.expansionState.isTrainingSessionExpanded,
      ),
    );
    _notifyTestListeners();
  }

  @override
  void toggleTrainingSessionGeneratorExpanded() {
    methodCalls.add('toggleTrainingSessionGeneratorExpanded');
    _testState = _testState.copyWith(
      expansionState: _testState.expansionState.copyWith(
        isTrainingSessionGeneratorExpanded: !_testState.expansionState.isTrainingSessionGeneratorExpanded,
      ),
    );
    _notifyTestListeners();
  }

  @override
  void toggleMachineFeaturesExpanded() {
    methodCalls.add('toggleMachineFeaturesExpanded');
    _testState = _testState.copyWith(
      expansionState: _testState.expansionState.copyWith(
        isMachineFeaturesExpanded: !_testState.expansionState.isMachineFeaturesExpanded,
      ),
    );
    _notifyTestListeners();
  }

  @override
  void toggleDeviceDataFeaturesExpanded() {
    methodCalls.add('toggleDeviceDataFeaturesExpanded');
    _testState = _testState.copyWith(
      expansionState: _testState.expansionState.copyWith(
        isDeviceDataFeaturesExpanded: !_testState.expansionState.isDeviceDataFeaturesExpanded,
      ),
    );
    _notifyTestListeners();
  }

  @override
  void updateFreeRideDuration(int minutes) {
    methodCalls.add('updateFreeRideDuration:$minutes');
  }

  @override
  void updateFreeRideDistance(int meters) {
    methodCalls.add('updateFreeRideDistance:$meters');
  }

  @override
  void updateFreeRideDistanceBased(bool isDistanceBased, {dynamic selectedGpxData}) {
    methodCalls.add('updateFreeRideDistanceBased:$isDistanceBased');
  }

  @override
  void updateFreeRideTarget(String name, dynamic value) {
    methodCalls.add('updateFreeRideTarget:$name:$value');
  }

  @override
  void updateFreeRideResistance({int? userLevel, bool validateOnly = false}) {
    methodCalls.add('updateFreeRideResistance:$userLevel');
  }

  @override
  void updateFreeRideWarmup(bool hasWarmup) {
    methodCalls.add('updateFreeRideWarmup:$hasWarmup');
  }

  @override
  void updateFreeRideCooldown(bool hasCooldown) {
    methodCalls.add('updateFreeRideCooldown:$hasCooldown');
  }

  @override
  void updateTrainingGeneratorDuration(int minutes) {
    methodCalls.add('updateTrainingGeneratorDuration:$minutes');
  }

  @override
  void updateTrainingGeneratorWorkoutType(dynamic workoutType) {
    methodCalls.add('updateTrainingGeneratorWorkoutType:$workoutType');
  }

  @override
  void updateTrainingGeneratorResistance({int? userLevel, bool validateOnly = false}) {
    methodCalls.add('updateTrainingGeneratorResistance:$userLevel');
  }

  @override
  void selectGpxRoute(String? assetPath, {dynamic gpxData}) {
    methodCalls.add('selectGpxRoute:$assetPath');
  }
}

Widget createTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  late MockBluetoothDevice mockDevice;
  late MockSessionSelectorService mockService;

  final testUserSettings = UserSettings(
    cyclingFtp: 200,
    rowingFtp: '2:00',
    developerMode: false,
    soundEnabled: true,
  );

  final testDisplayConfig = LiveDataDisplayConfig(
    fields: [],
    deviceType: DeviceType.rower,
  );

  setUp(() {
    mockDevice = MockBluetoothDevice();
  });

  group('FTMSessionSelectorTab', () {
    group('Initial State', () {
      testWidgets('shows loading indicator when deviceType is null', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: const SessionSelectorState(
            status: SessionSelectorLoadingStatus.initial,
            deviceType: null,
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows loading indicator when status is loading', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: const SessionSelectorState(
            status: SessionSelectorLoadingStatus.loading,
            deviceType: DeviceType.rower,
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows error message when status is error', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: const SessionSelectorState(
            status: SessionSelectorLoadingStatus.error,
            errorMessage: 'Test error message',
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pump();

        expect(find.text('Test error message'), findsOneWidget);
      });
    });

    group('Developer Mode Required', () {
      testWidgets('shows developer mode required when device not available', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: false,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Developer Mode Required'), findsOneWidget);
        expect(find.byIcon(Icons.developer_mode), findsOneWidget);
        expect(find.text('Go Back'), findsOneWidget);
      });
    });

    group('Content Rendering', () {
      testWidgets('shows Free Ride section when loaded', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Free Ride'), findsOneWidget);
      });

      testWidgets('shows Load Training Session section', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Load Training Session'), findsOneWidget);
      });

      testWidgets('shows Training Session Generator for rower', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Training Session Generator'), findsOneWidget);
      });

      testWidgets('does not show Training Session Generator for indoor bike', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.indoorBike,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.indoorBike: LiveDataDisplayConfig(fields: [], deviceType: DeviceType.indoorBike)},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Training Session Generator'), findsNothing);
      });

      testWidgets('shows developer-only sections when developerMode is true', (WidgetTester tester) async {
        final devUserSettings = UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: true,
          soundEnabled: true,
        );

        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: devUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Device Data Features'), findsOneWidget);
        expect(find.text('Machine Features'), findsOneWidget);
      });

      testWidgets('hides developer sections when developerMode is false', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings, // developerMode: false
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Device Data Features'), findsNothing);
        expect(find.text('Machine Features'), findsNothing);
      });
    });

    group('Expansion Panel Interactions', () {
      testWidgets('toggles Free Ride expansion when tapped', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap on Free Ride section
        await tester.tap(find.text('Free Ride'));
        await tester.pumpAndSettle();

        expect(mockService.methodCalls, contains('toggleFreeRideExpanded'));
      });

      testWidgets('toggles Load Training Session expansion when tapped', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap on Load Training Session section
        await tester.tap(find.text('Load Training Session'));
        await tester.pumpAndSettle();

        expect(mockService.methodCalls, contains('toggleTrainingSessionExpanded'));
      });

      testWidgets('toggles Training Session Generator expansion when tapped', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap on Training Session Generator section
        await tester.tap(find.text('Training Session Generator'));
        await tester.pumpAndSettle();

        expect(mockService.methodCalls, contains('toggleTrainingSessionGeneratorExpanded'));
      });
    });

    group('Training Sessions Content', () {
      testWidgets('shows loading indicator when loading training sessions', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
            isLoadingTrainingSessions: true,
            expansionState: const ExpansionState(isTrainingSessionExpanded: true),
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        // Use pump() instead of pumpAndSettle() since loading spinner keeps animating
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Find CircularProgressIndicator inside the training sessions section
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows error message when training sessions failed to load', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
            trainingSessions: null, // null indicates failed to load
            isLoadingTrainingSessions: false,
            expansionState: const ExpansionState(isTrainingSessionExpanded: true),
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Failed to load training sessions.'), findsOneWidget);
      });

      testWidgets('shows no sessions message when list is empty', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
            trainingSessions: [], // empty list
            isLoadingTrainingSessions: false,
            expansionState: const ExpansionState(isTrainingSessionExpanded: true),
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('No training sessions found for this machine type.'), findsOneWidget);
      });
    });

    group('Service Lifecycle', () {
      testWidgets('initializes service on mount', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));

        expect(mockService.methodCalls, contains('initialize'));
      });

      testWidgets('passes ftmsDevice to widget', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: const SessionSelectorState(),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));

        final widget = tester.widget<FTMSessionSelectorTab>(find.byType(FTMSessionSelectorTab));
        expect(widget.ftmsDevice, mockDevice);
      });
    });

    group('Expandable Card Display', () {
      testWidgets('shows expand_more icon when collapsed', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
            expansionState: const ExpansionState(isFreeRideExpanded: false),
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        // Should have expand_more icons for collapsed sections
        expect(find.byIcon(Icons.expand_more), findsWidgets);
      });

      testWidgets('shows expand_less icon when expanded', (WidgetTester tester) async {
        mockService = MockSessionSelectorService(
          ftmsDevice: mockDevice,
          initialState: SessionSelectorState(
            status: SessionSelectorLoadingStatus.loaded,
            deviceType: DeviceType.rower,
            isDeviceAvailable: true,
            userSettings: testUserSettings,
            configs: {DeviceType.rower: testDisplayConfig},
            expansionState: const ExpansionState(
              isFreeRideExpanded: true,
              isTrainingSessionExpanded: true,
              isTrainingSessionGeneratorExpanded: true,
            ),
          ),
        );

        await tester.pumpWidget(createTestApp(
          child: FTMSessionSelectorTab(
            ftmsDevice: mockDevice,
            writeCommand: (_) async {},
            service: mockService,
          ),
        ));
        await tester.pumpAndSettle();

        // Should have expand_less icons for expanded sections
        expect(find.byIcon(Icons.expand_less), findsWidgets);
      });
    });
  });
}
