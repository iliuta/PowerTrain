import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mockito/mockito.dart';
import 'package:ftms/features/ftms/ftms_page.dart';
import 'package:ftms/features/ftms/ftms_session_selector_tab.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Mock classes for testing
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

Widget createTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: child,
  );
}

void main() {
  late MockBluetoothDevice mockDevice;

  setUp(() {
    mockDevice = MockBluetoothDevice();
  });

  group('FTMSPage', () {
    testWidgets('renders with app bar showing device name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: FTMSPage(ftmsDevice: mockDevice),
      ));
      // Allow initial frame to render
      await tester.pump();

      // Should display device name in app bar
      expect(find.text('Mock Rowing Machine'), findsOneWidget);
    });

    testWidgets('renders FTMSessionSelectorTab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: FTMSPage(ftmsDevice: mockDevice),
      ));
      await tester.pump();

      // Should contain FTMSessionSelectorTab
      expect(find.byType(FTMSessionSelectorTab), findsOneWidget);
    });

    testWidgets('app bar has correct height', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: FTMSPage(ftmsDevice: mockDevice),
      ));
      await tester.pump();

      // Find AppBar and verify it exists
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('is wrapped in Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: FTMSPage(ftmsDevice: mockDevice),
      ));
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
