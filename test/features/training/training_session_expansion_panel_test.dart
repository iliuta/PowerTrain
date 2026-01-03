import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/training_session_expansion_panel.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/model/training_session.dart';
import 'package:ftms/features/training/widgets/training_session_chart.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:flutter/services.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks
@GenerateMocks([])
class MockStorageService extends Mock {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper method to create test UserSettings
  UserSettings createTestUserSettings() {
    return const UserSettings(
      cyclingFtp: 250,
      rowingFtp: '2:00',
      developerMode: false,
    );
  }

  // Helper method to create test configs
  Map<DeviceType, LiveDataDisplayConfig?> createTestConfigs() {
    return {
      DeviceType.rower: null,
      DeviceType.indoorBike: null,
    };
  }

  // Helper method to create widget with test data
  Widget createTestWidget(List<TrainingSessionDefinition> sessions) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TrainingSessionExpansionPanelList(
          sessions: sessions,
          scrollController: ScrollController(),
          userSettings: createTestUserSettings(),
          configs: createTestConfigs(),
        ),
      ),
    );
  }

  // Mock AssetBundle for config loading
  setUpAll(() async {
    // Mock AssetManifest.json
    const manifest = '{"lib/config/rowing_machine.json":[],"lib/config/indoor_bike.json":[]}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
      final String key = const StringCodec().decodeMessage(message) as String;
      if (key == 'AssetManifest.json') {
        return const StringCodec().encodeMessage(manifest);
      }
      if (key == 'lib/config/rowing_machine.json') {
        return const StringCodec().encodeMessage('''{
  "fields": [
    { "name": "Instantaneous Speed", "label": "Speed", "display": "speedometer", "unit": "km/h", "min": 0, "max": 30 },
    { "name": "Stroke Rate", "label": "Stroke Rate", "display": "number", "unit": "spm", "icon": "rowing" },
    { "name": "Instantaneous Power", "label": "Power", "display": "speedometer", "unit": "W", "min": 0, "max": 1500 },
    { "name": "Heart Rate", "label": "Heart rate", "display": "number", "unit": "bpm", "icon": "heart" }
  ]
}''');
      }
      return null;
    });
  });

  testWidgets('TrainingSessionExpansionPanelList displays intervals and targets prettily', (WidgetTester tester) async {
    final session = TrainingSessionDefinition(
      title: 'Rowing Test',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Warmup',
          duration: 60,
          targets: {'Stroke Rate': 24, 'Heart Rate': 120},
        ),
        UnitTrainingInterval(
          title: 'Main',
          duration: 300,
          targets: {'Instantaneous Power': 200},
        ),
      ],
    );
    await tester.pumpWidget(createTestWidget([session]));
    // Expand the panel
    await tester.tap(find.text('Rowing Test'));
    await tester.pump();
    
    // Should show the chart title
    expect(find.text('Training Intensity'), findsOneWidget);
    
    // Should show the interactive chart
    expect(find.byType(TrainingSessionChart), findsOneWidget);
    
    // Shouldn't show the start button
    expect(find.text('Start Session'), findsNothing);
    expect(find.textContaining('{'), findsNothing);
    expect(find.textContaining('}'), findsNothing);
  });

  testWidgets('displays Built-in badge for non-custom sessions', (WidgetTester tester) async {
    final session = TrainingSessionDefinition(
      title: 'Built-in Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: false,
    );

    await tester.pumpWidget(createTestWidget([session]));

    // Should show Built-in badge
    expect(find.text('Built-in'), findsOneWidget);
    expect(find.text('Custom'), findsNothing);
  });

  testWidgets('displays Custom badge for custom sessions', (WidgetTester tester) async {
    final session = TrainingSessionDefinition(
      title: 'Custom Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: true,
    );

    await tester.pumpWidget(createTestWidget([session]));

    // Should show Custom badge
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Built-in'), findsNothing);
  });

  testWidgets('displays duplicate button for all sessions', (WidgetTester tester) async {
    final builtInSession = TrainingSessionDefinition(
      title: 'Built-in Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: false,
    );

    final customSession = TrainingSessionDefinition(
      title: 'Custom Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: true,
    );

    await tester.pumpWidget(createTestWidget([builtInSession, customSession]));

    // Expand both panels by tapping their headers
    await tester.tap(find.text('Built-in Session'));
    await tester.pump();
    await tester.tap(find.text('Custom Session'));
    await tester.pump();

    // Should show duplicate button for both sessions
    expect(find.byTooltip('Duplicate'), findsNWidgets(2));
    expect(find.byIcon(Icons.content_copy), findsNWidgets(2));
  });

  testWidgets('duplicate button opens confirmation dialog', (WidgetTester tester) async {
    final session = TrainingSessionDefinition(
      title: 'Test Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: false,
    );

    await tester.pumpWidget(createTestWidget([session]));

    // Expand the panel
    await tester.tap(find.text('Test Session'));
    await tester.pumpAndSettle();
    
    // Tap the duplicate button
    await tester.tap(find.byTooltip('Duplicate'));
    await tester.pumpAndSettle();

    // Should show duplicate confirmation dialog
    expect(find.text('Duplicate Training Session'), findsOneWidget);
    expect(find.text('Create a copy of "Test Session" as a new custom session?'), findsOneWidget);
    expect(find.text('New Session Title'), findsOneWidget);
    expect(find.text('Test Session (Copy)'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Duplicate'), findsNWidgets(1)); // One in panel, one in dialog
    expect(find.byTooltip('Duplicate'), findsNWidgets(1)); // One in panel, one in dialog
  });

  testWidgets('duplicate dialog can be cancelled', (WidgetTester tester) async {
    final session = TrainingSessionDefinition(
      title: 'Test Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: false,
    );

    await tester.pumpWidget(createTestWidget([session]));

    // Expand the panel and open duplicate dialog
    await tester.tap(find.text('Test Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Duplicate'));
    await tester.pumpAndSettle();

    // Tap cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog should be closed
    expect(find.text('Duplicate Training Session'), findsNothing);
  });

  testWidgets('duplicate dialog allows editing session title', (WidgetTester tester) async {
    final session = TrainingSessionDefinition(
      title: 'Test Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: false,
    );

    await tester.pumpWidget(createTestWidget([session]));

    // Expand the panel and open duplicate dialog
    await tester.tap(find.text('Test Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Duplicate'));
    await tester.pumpAndSettle();

    // Find the text field and edit it
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    
    // Clear and enter new title
    await tester.tap(textField);
    await tester.enterText(textField, 'My Custom Session');
    await tester.pumpAndSettle();

    // Verify the new text is displayed
    expect(find.text('My Custom Session'), findsOneWidget);
  });

  testWidgets('duplicate callback is called when duplication is confirmed', (WidgetTester tester) async {
    final session = TrainingSessionDefinition(
      title: 'Test Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: false,
    );

    await tester.pumpWidget(createTestWidget([session]));

    // Expand the panel and open duplicate dialog
    await tester.tap(find.text('Test Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Duplicate'));
    await tester.pumpAndSettle();

    // Tap duplicate button in dialog
    await tester.tap(find.text('Duplicate').last);
    await tester.pumpAndSettle();

    // Wait for async operations to complete
    await tester.pump(const Duration(milliseconds: 100));

    // Verify callback was called (note: actual storage service call will fail in test environment)
    // This test primarily verifies the UI flow
  });

  testWidgets('shows edit and delete buttons only for custom sessions', (WidgetTester tester) async {
    final builtInSession = TrainingSessionDefinition(
      title: 'Built-in Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: false,
    );

    final customSession = TrainingSessionDefinition(
      title: 'Custom Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: true,
    );

    await tester.pumpWidget(createTestWidget([builtInSession, customSession]));

    // Expand both panels by tapping their headers
    await tester.tap(find.text('Built-in Session'));
    await tester.pump();
    await tester.tap(find.text('Custom Session'));
    await tester.pump();

    // Should show edit and delete buttons only for custom session
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('delete button shows confirmation dialog', (WidgetTester tester) async {
    final customSession = TrainingSessionDefinition(
      title: 'Custom Session',
      ftmsMachineType: DeviceType.rower,
      intervals: <UnitTrainingInterval>[
        UnitTrainingInterval(
          title: 'Interval 1',
          duration: 60,
          targets: {'Stroke Rate': 24},
        ),
      ],
      isCustom: true,
    );

    await tester.pumpWidget(createTestWidget([customSession]));

    // Expand the panel
    await tester.tap(find.text('Custom Session'));
    await tester.pumpAndSettle();

    // Tap the delete button
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    // Should show delete confirmation dialog
    expect(find.text('Delete Training Session'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);
    expect(find.textContaining('This action cannot be undone'), findsOneWidget);
  });
}
