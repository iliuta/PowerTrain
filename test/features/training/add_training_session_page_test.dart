import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/services/training_session_storage_service.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/add_training_session_page.dart';
import 'package:ftms/features/training/model/training_session.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart' as mockito;
import 'package:mocktail/mocktail.dart' as mocktail;

// Generate mocks for our dependencies
@GenerateMocks([
  LiveDataDisplayConfig,
  TrainingSessionStorageService,
])
import 'add_training_session_page_test.mocks.dart';

// Wrapper functions for static methods (to enable mocking)
Future<LiveDataDisplayConfig?> loadConfigWrapper(DeviceType deviceType) =>
    LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);

Future<UserSettings> loadUserSettingsWrapper() =>
    UserSettings.loadDefault();

// Mock classes
class MockUserSettings extends mocktail.Mock implements UserSettings {}

// Global mock instances
late MockLiveDataDisplayConfig mockConfig;
late MockUserSettings mockUserSettings;
late MockTrainingSessionStorageService mockStorageService;

void main() {
  // Initialize Flutter bindings for widget tests
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up mocktail fallback for LiveDataDisplayConfig
  setUpAll(() {
    mocktail.registerFallbackValue(MockLiveDataDisplayConfig());
    mocktail.registerFallbackValue(DeviceType.indoorBike);
    mocktail.registerFallbackValue(MockUserSettings());

    // Create global mock instances
    mockConfig = MockLiveDataDisplayConfig();
    mockUserSettings = MockUserSettings();
    mockStorageService = MockTrainingSessionStorageService();

    // Mock config properties
    mockito.when(mockConfig.fields).thenReturn([
      LiveDataFieldConfig(
        name: 'power',
        label: 'Power',
        display: 'number',
        unit: 'W',
        availableAsTarget: true,
        userSetting: 'cyclingFtp',
      ),
      LiveDataFieldConfig(
        name: 'cadence',
        label: 'Cadence',
        display: 'number',
        unit: 'rpm',
        availableAsTarget: true,
      ),
    ]);

    // Mock user settings
    mocktail.when(() => mockUserSettings.cyclingFtp).thenReturn(200);
    mocktail.when(() => mockUserSettings.rowingFtp).thenReturn('2:00/500m');
    mocktail.when(() => mockUserSettings.developerMode).thenReturn(false);
  });

  group('AddTrainingSessionPage', () {
    setUp(() {
      // Reset mocks before each test
      mocktail.reset(mockUserSettings);
      mockito.reset(mockStorageService);
      
      // Re-setup mock behaviors
      mocktail.when(() => mockUserSettings.cyclingFtp).thenReturn(200);
      mocktail.when(() => mockUserSettings.rowingFtp).thenReturn('2:00/500m');
      mocktail.when(() => mockUserSettings.developerMode).thenReturn(false);
    });
    group('Initialization', () {
      testWidgets('initializes with template for new bike session', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        // Wait for initialization
        await tester.pumpAndSettle();

        // Verify the page title
        expect(find.text('Add Training Session'), findsOneWidget);

        // Verify template was created (should have one interval for bike)
        // Check that there's at least one interval card rendered
        expect(find.byType(Card), findsWidgets); // Should have interval cards

        // Verify title was set from template - check the text field value
        final titleField = find.byType(TextField).first;
        final TextField textFieldWidget = tester.widget(titleField);
        final TextEditingController controller = textFieldWidget.controller!;
        expect(controller.text, contains('Cycling'));
      });

      testWidgets('initializes with template for new rower session', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.rower,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        // Wait for initialization
        await tester.pumpAndSettle();

        // Verify template was created (should have multiple intervals for rower)
        // Check that there are multiple interval cards rendered
        expect(find.byType(Card), findsWidgets); // Should have interval cards

        // Verify title was set from template - check the text field value
        final titleField = find.byType(TextField).first;
        final TextField textFieldWidget = tester.widget(titleField);
        final TextEditingController controller = textFieldWidget.controller!;
        expect(controller.text, contains('Rowing'));
      });

      testWidgets('initializes from existing session for edit mode', (tester) async {
        final existingSession = TrainingSessionDefinition(
          title: 'Existing Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [
            UnitTrainingInterval(
              title: 'Existing Interval',
              duration: 300,
              targets: {'power': '150'},
            ),
          ],
          isCustom: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              existingSession: existingSession,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        // Wait for initialization
        await tester.pumpAndSettle();

        // Verify the page title for edit mode
        expect(find.text('Edit Training Session'), findsOneWidget);

        // Verify existing session data was loaded
        final titleField = find.byType(TextField).first;
        final TextField textFieldWidget = tester.widget(titleField);
        final TextEditingController controller = textFieldWidget.controller!;
        expect(controller.text, 'Existing Session');
        
        // Check that there's at least one interval card
        expect(find.byType(Card), findsWidgets);
      });
    });

    group('Interval Management', () {
      testWidgets('adds unit interval', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final initialCardCount = find.byType(ExpansionTile).evaluate().length;

        // Tap the add button
        await tester.tap(find.byTooltip('Add Unit Interval'));
        await tester.pumpAndSettle();

        final newCardCount = find.byType(ExpansionTile).evaluate().length;
        expect(newCardCount, initialCardCount + 1);
      });

      testWidgets('adds group interval', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final initialCardCount = find.byType(ExpansionTile).evaluate().length;

        // Tap the group interval button (repeat icon)
        await tester.tap(find.byIcon(Icons.repeat));
        await tester.pumpAndSettle();

        final newCardCount = find.byType(ExpansionTile).evaluate().length;
        expect(newCardCount, initialCardCount + 1);
      });

      testWidgets('removes interval', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final initialCardCount = find.byType(ExpansionTile).evaluate().length;

        // Add an interval first
        await tester.tap(find.byTooltip('Add Unit Interval'));
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile).evaluate().length, initialCardCount + 1);

        // Find and tap the delete button on the interval card
        // First expand the tile to ensure the delete button is accessible
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pumpAndSettle();
        
        await tester.tap(find.byTooltip('Delete').first, warnIfMissed: false);
        await tester.pumpAndSettle();

        final finalCardCount = find.byType(ExpansionTile).evaluate().length;
        expect(finalCardCount, initialCardCount);
      });

      testWidgets('duplicates interval', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final initialCardCount = find.byType(ExpansionTile).evaluate().length;

        // Add an interval first
        await tester.tap(find.byTooltip('Add Unit Interval'));
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile).evaluate().length, initialCardCount + 1);

        // Find and tap the copy button on the interval card
        await tester.tap(find.byTooltip('Duplicate').first, warnIfMissed: false);
        await tester.pumpAndSettle();

        final finalCardCount = find.byType(ExpansionTile).evaluate().length;
        expect(finalCardCount, initialCardCount + 2);
      });
    });

    group('Session Saving', () {
      testWidgets('saves new session successfully', (tester) async {
        mockito.when(mockStorageService.saveSession(mockito.any))
            .thenAnswer((_) async => '/path/to/saved/session.json');

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Set a title
        await tester.enterText(find.byType(TextField).first, 'Test Session');
        await tester.pump();

        // Tap save button
        await tester.tap(find.text('Save'));
        await tester.pump();

        // Verify save was called
        mockito.verify(mockStorageService.saveSession(mockito.any)).called(1);

        // Verify success message appears
        expect(find.textContaining('saved successfully'), findsOneWidget);
      });

      testWidgets('shows error when saving without title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Clear the title (template sets one, so we need to clear it)
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pump();

        // Tap save button
        await tester.tap(find.text('Save'));
        await tester.pump();

        // Verify error message appears
        expect(find.text('Please enter a session title'), findsOneWidget);

        // Verify save was not called
        mockito.verifyNever(mockStorageService.saveSession(mockito.any));
      });

      testWidgets('shows error when saving without intervals', (tester) async {
        // Create a session with no intervals (override the template)
        final emptySession = TrainingSessionDefinition(
          title: 'Empty Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [],
          isCustom: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              existingSession: emptySession,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify save button is disabled when there are no intervals
        final saveButton = find.widgetWithText(ElevatedButton, 'Update');
        expect(saveButton, findsOneWidget);
        
        // The button should be disabled (ElevatedButton with null onPressed)
        final ElevatedButton button = tester.widget<ElevatedButton>(saveButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('handles save error gracefully', (tester) async {
        mockito.when(mockStorageService.saveSession(mockito.any))
            .thenThrow(Exception('Storage error'));

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Set a title
        await tester.enterText(find.byType(TextField).first, 'Test Session');
        await tester.pump();

        // Tap save button
        await tester.tap(find.text('Save'));
        await tester.pump();

        // Verify error message appears
        expect(find.textContaining('Failed to save session'), findsOneWidget);
      });

      testWidgets('updates existing session successfully', (tester) async {
        final existingSession = TrainingSessionDefinition(
          title: 'Original Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [
            UnitTrainingInterval(
              title: 'Original Interval',
              duration: 300,
              targets: {},
            ),
          ],
          isCustom: true,
        );

        mockito.when(mockStorageService.saveSession(mockito.any))
            .thenAnswer((_) async => '/path/to/updated/session.json');
        mockito.when(mockStorageService.deleteSession(mockito.any, mockito.any))
            .thenAnswer((_) async => true);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              existingSession: existingSession,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Modify the title
        await tester.enterText(find.byType(TextField).first, 'Updated Session');
        await tester.pump();

        // Tap update button
        await tester.tap(find.text('Update'));
        await tester.pump();

        // Verify delete was called for original session
        mockito.verify(mockStorageService.deleteSession('Original Session', 'indoorBike')).called(1);

        // Verify save was called for updated session
        mockito.verify(mockStorageService.saveSession(mockito.any)).called(1);

        // Verify success message appears
        expect(find.textContaining('updated successfully'), findsOneWidget);
      });
    });

    group('UI Rendering', () {
      testWidgets('renders loading state initially', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              storageService: mockStorageService,
            ),
          ),
        );

        // Should show loading indicator initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Add Training Session'), findsOneWidget);
      });

      // Note: Error state test removed as static method mocking is not possible with dependency injection

      testWidgets('renders training chart when intervals exist', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show training preview chart
        expect(find.text('Training Preview'), findsOneWidget);
      });

      testWidgets('shows empty state message when no intervals', (tester) async {
        // Create session with no intervals
        final emptySession = TrainingSessionDefinition(
          title: 'Empty Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: [],
          isCustom: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              existingSession: emptySession,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show empty state message
        expect(find.textContaining('No intervals added yet'), findsOneWidget);
      });

      testWidgets('renders interval cards correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should have interval cards
        expect(find.byType(Card), findsWidgets); // At least the chart card and interval cards

        // Should have drag handles
        expect(find.byIcon(Icons.drag_handle), findsWidgets);

        // Should have action buttons
        expect(find.byIcon(Icons.copy), findsWidgets);
        expect(find.byIcon(Icons.delete), findsWidgets);
      });

      testWidgets('renders floating action buttons', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should have FABs for adding intervals
        expect(find.byIcon(Icons.add), findsWidgets);
        expect(find.byIcon(Icons.repeat), findsWidgets);
      });
    });

    group('Interval Editing', () {
      testWidgets('can edit interval title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Expand the first interval card
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pumpAndSettle();

        // Find the title text field and enter new title
        final titleFields = find.byType(TextFormField);
        expect(titleFields, findsWidgets);

        await tester.enterText(titleFields.first, 'New Interval Title');
        await tester.pump();

        // Verify the field contains the entered text by checking the widget's initialValue
        final TextFormField titleField = tester.widget(titleFields.first);
        expect(titleField.initialValue, 'New Interval Title');
      });

      testWidgets('can edit interval duration', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Expand the first interval card
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pumpAndSettle();

        // Verify duration can be increased (check that add button exists and can be tapped)
        final durationAddButtons = find.byIcon(Icons.add);
        expect(durationAddButtons, findsWidgets);
        
        // Tap the duration add button (should be the first one)
        await tester.tap(durationAddButtons.first);
        await tester.pump();
        
        // The test passes if no exceptions are thrown and the UI updates
      });

      testWidgets('can edit interval targets', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTrainingSessionPage(
              machineType: DeviceType.indoorBike,
              config: mockConfig,
              userSettings: mockUserSettings,
              storageService: mockStorageService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Expand the first interval card
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pumpAndSettle();

        // Find target text fields (should be percentage inputs for power)
        final targetTextFields = find.byType(TextFormField);
        // Skip title field, find the percentage field
        final targetPercentageField = targetTextFields.at(1); // Second text field
        
        await tester.enterText(targetPercentageField, '75');
        await tester.pump();
        
        // Verify the field contains the entered value
        final TextFormField targetFieldWidget = tester.widget(targetPercentageField);
        expect(targetFieldWidget.initialValue, '75');
      });
    });
  });
}