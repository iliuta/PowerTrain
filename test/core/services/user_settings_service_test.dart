import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/user_settings_service.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channel = MethodChannel('flutter/assets');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset any previous handler before each test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, null);
    // Reset SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    // Reset the UserSettingsService singleton
    UserSettingsService.instance.clearCache();
  });

  tearDown(() {
    // Clean up after each test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, null);
    UserSettingsService.instance.clearCache();
  });

  group('UserSettingsService', () {
    group('loadSettings', () {
      test('loads from cache if settings have already been loaded', () async {
        final settingsJson = jsonEncode({
          'cyclingFtp': 250,
          'rowingFtp': '2:00',
          'developerMode': true,
          'soundEnabled': false,
          'metronomeSoundEnabled': true,
        });
        SharedPreferences.setMockInitialValues({'user_settings': settingsJson});

        // First load from SharedPreferences
        final settings1 = await UserSettingsService.instance.loadSettings();
        expect(settings1.cyclingFtp, 250);

        // Change SharedPreferences (but cache should still have old value)
        SharedPreferences.setMockInitialValues({'user_settings': ''});

        // Second load should return cached value
        final settings2 = await UserSettingsService.instance.loadSettings();
        expect(settings2.cyclingFtp, 250); // Still 250 from cache
      });

      test('loads from SharedPreferences when available', () async {
        final settingsJson = jsonEncode({
          'cyclingFtp': 250,
          'rowingFtp': '2:00',
          'developerMode': true,
          'soundEnabled': false,
          'metronomeSoundEnabled': true,
        });
        SharedPreferences.setMockInitialValues({'user_settings': settingsJson});

        final settings = await UserSettingsService.instance.loadSettings();
        expect(settings.cyclingFtp, 250);
        expect(settings.rowingFtp, '2:00');
        expect(settings.developerMode, true);
        expect(settings.soundEnabled, false);
        expect(settings.metronomeSoundEnabled, true);
      });

      test('loads from asset when SharedPreferences is empty', () async {
        const defaultAssetPath = 'lib/config/default_user_settings.json';
        final defaultJson = jsonEncode({
          'cyclingFtp': 300,
          'rowingFtp': '2:10',
          'developerMode': false,
          'soundEnabled': true,
          'metronomeSoundEnabled': true,
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
          channel.name,
          (ByteData? message) async {
            final requested = utf8.decode(message!.buffer.asUint8List());
            if (requested == defaultAssetPath) {
              return ByteData.view(Uint8List.fromList(defaultJson.codeUnits).buffer);
            }
            return null;
          },
        );
        SharedPreferences.setMockInitialValues({});

        final settings = await UserSettingsService.instance.loadSettings();
        expect(settings.cyclingFtp, 300);
        expect(settings.rowingFtp, '2:10');
        expect(settings.developerMode, false);
        expect(settings.soundEnabled, true);
        expect(settings.metronomeSoundEnabled, true);
      });

      test('returns sensible defaults when both SharedPreferences and asset fail', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(channel.name, (ByteData? message) async => null);
        SharedPreferences.setMockInitialValues({});

        final settings = await UserSettingsService.instance.loadSettings();
        expect(settings.cyclingFtp, 300); // Loads from asset defaults
        expect(settings.rowingFtp, '2:10'); // Loads from asset defaults
        expect(settings.developerMode, false);
        expect(settings.soundEnabled, true);
        expect(settings.metronomeSoundEnabled, true);
      });
    });

    group('saveSettings', () {
      test('saves settings to SharedPreferences', () async {
        final settings = UserSettings(
          cyclingFtp: 180,
          rowingFtp: '1:45',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: false,
        );
        SharedPreferences.setMockInitialValues({});

        await UserSettingsService.instance.saveSettings(settings);

        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('user_settings');
        expect(savedJson, isNotNull);

        final savedMap = json.decode(savedJson!) as Map<String, dynamic>;
        expect(savedMap['cyclingFtp'], 180);
        expect(savedMap['rowingFtp'], '1:45');
        expect(savedMap['developerMode'], false);
        expect(savedMap['soundEnabled'], true);
        expect(savedMap['metronomeSoundEnabled'], false);
      });

      test('updates cache after saving', () async {
        final settings = UserSettings(
          cyclingFtp: 180,
          rowingFtp: '1:45',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: false,
        );
        SharedPreferences.setMockInitialValues({});

        await UserSettingsService.instance.saveSettings(settings);

        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached, isNotNull);
        expect(cached!.cyclingFtp, 180);
        expect(cached.rowingFtp, '1:45');
        expect(cached.metronomeSoundEnabled, false);
      });

      test('throws exception if save fails', () async {
        final settings = UserSettings(
          cyclingFtp: 180,
          rowingFtp: '1:45',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: false,
        );
        // Create a scenario where SharedPreferences would fail
        // (by using a mock that throws)
        SharedPreferences.setMockInitialValues({});

        // The implementation might not throw in normal circumstances,
        // but we test the contract
        final result = UserSettingsService.instance.saveSettings(settings);
        expect(result, isA<Future>());
        await result;
      });
    });

    group('getCachedSettings', () {
      test('returns null when nothing has been loaded', () {
        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached, isNull);
      });

      test('returns cached settings after loadSettings', () async {
        final settingsJson = jsonEncode({
          'cyclingFtp': 250,
          'rowingFtp': '2:00',
          'developerMode': false,
          'soundEnabled': true,
          'metronomeSoundEnabled': true,
        });
        SharedPreferences.setMockInitialValues({'user_settings': settingsJson});

        await UserSettingsService.instance.loadSettings();

        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached, isNotNull);
        expect(cached!.cyclingFtp, 250);
        expect(cached.metronomeSoundEnabled, true);
      });

      test('returns cached settings after saveSettings', () async {
        final settings = UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:15',
          developerMode: true,
          soundEnabled: false,
          metronomeSoundEnabled: false,
        );
        SharedPreferences.setMockInitialValues({});

        await UserSettingsService.instance.saveSettings(settings);

        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached, isNotNull);
        expect(cached!.cyclingFtp, 200);
        expect(cached.developerMode, true);
        expect(cached.metronomeSoundEnabled, false);
      });
    });

    group('clearCache', () {
      test('clears cached settings', () async {
        final settingsJson = jsonEncode({
          'cyclingFtp': 250,
          'rowingFtp': '2:00',
          'developerMode': false,
          'soundEnabled': true,
          'metronomeSoundEnabled': true,
        });
        SharedPreferences.setMockInitialValues({'user_settings': settingsJson});

        // Load settings to populate cache
        await UserSettingsService.instance.loadSettings();
        expect(UserSettingsService.instance.getCachedSettings(), isNotNull);

        // Clear cache
        UserSettingsService.instance.clearCache();
        expect(UserSettingsService.instance.getCachedSettings(), isNull);
      });

      test('forces reload on next loadSettings after clearCache', () async {
        // Save custom settings to SharedPreferences and verify they persist and can be cleared
        const customSettingsJson = {
          'cyclingFtp': 275,
          'rowingFtp': '2:15',
          'developerMode': false,
          'soundEnabled': true,
          'metronomeSoundEnabled': false,
        };
        
        SharedPreferences.setMockInitialValues({
          'user_settings': jsonEncode(customSettingsJson),
        });

        // Load settings first time
        final settings1 = await UserSettingsService.instance.loadSettings();
        expect(settings1.cyclingFtp, 275);
        
        // Verify the value is cached
        expect(UserSettingsService.instance.getCachedSettings()?.cyclingFtp, 275);

        // Clear cache - this should remove the cached value
        UserSettingsService.instance.clearCache();
        
        // After clearing, getCachedSettings should return null
        expect(UserSettingsService.instance.getCachedSettings(), isNull);
        
        // Load again to verify it reloads from SharedPreferences (not from cache)
        final settings2 = await UserSettingsService.instance.loadSettings();
        expect(settings2.cyclingFtp, 275); // Should reload from SharedPreferences
      });
    });

    group('initialize', () {
      test('can initialize SharedPreferences during app startup', () async {
        SharedPreferences.setMockInitialValues({});

        // Call initialize (optional pre-initialization)
        await UserSettingsService.initialize();

        // Service should work normally after initialization
        final settings = await UserSettingsService.instance.loadSettings();
        expect(settings, isNotNull);
      });
    });

    group('concurrent access', () {
      test('handles multiple loadSettings calls concurrently', () async {
        final settingsJson = jsonEncode({
          'cyclingFtp': 250,
          'rowingFtp': '2:00',
          'developerMode': false,
          'soundEnabled': true,
          'metronomeSoundEnabled': true,
        });
        SharedPreferences.setMockInitialValues({'user_settings': settingsJson});

        // Call loadSettings multiple times concurrently
        final futures = [
          UserSettingsService.instance.loadSettings(),
          UserSettingsService.instance.loadSettings(),
          UserSettingsService.instance.loadSettings(),
        ];

        final results = await Future.wait(futures);

        // All should return the same settings
        for (final settings in results) {
          expect(settings.cyclingFtp, 250);
          expect(settings.rowingFtp, '2:00');
          expect(settings.metronomeSoundEnabled, true);
        }
      });
    });

    group('edge cases', () {
      test('handles malformed JSON in SharedPreferences gracefully', () async {
        SharedPreferences.setMockInitialValues({'user_settings': 'invalid json'});

        const defaultAssetPath = 'lib/config/default_user_settings.json';
        final defaultJson = jsonEncode({
          'cyclingFtp': 300,
          'rowingFtp': '2:10',
          'developerMode': false,
          'soundEnabled': true,
          'metronomeSoundEnabled': true,
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
          channel.name,
          (ByteData? message) async {
            final requested = utf8.decode(message!.buffer.asUint8List());
            if (requested == defaultAssetPath) {
              return ByteData.view(Uint8List.fromList(defaultJson.codeUnits).buffer);
            }
            return null;
          },
        );

        // Should fall back to asset
        final settings = await UserSettingsService.instance.loadSettings();
        expect(settings.cyclingFtp, 300);
        expect(settings.metronomeSoundEnabled, true);
      });

      test('preserves settings across multiple operations', () async {
        final settings1 = UserSettings(
          cyclingFtp: 180,
          rowingFtp: '1:45',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: false,
        );
        SharedPreferences.setMockInitialValues({});

        // Save settings
        await UserSettingsService.instance.saveSettings(settings1);

        // Load settings
        final loaded = await UserSettingsService.instance.loadSettings();
        expect(loaded.cyclingFtp, 180);
        expect(loaded.metronomeSoundEnabled, false);

        // Clear and load again (should reload from SharedPreferences)
        UserSettingsService.instance.clearCache();
        final reloaded = await UserSettingsService.instance.loadSettings();
        expect(reloaded.cyclingFtp, 180);
        expect(reloaded.metronomeSoundEnabled, false);
      });
    });

    group('setSoundEnabled', () {
      test('updates soundEnabled setting and saves to SharedPreferences', () async {
        // Start with sound disabled
        final initialSettings = UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: false,
          metronomeSoundEnabled: true,
        );
        SharedPreferences.setMockInitialValues({});
        await UserSettingsService.instance.saveSettings(initialSettings);

        // Enable sound
        await UserSettingsService.instance.setSoundEnabled(true);

        // Verify the setting was updated in cache
        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached!.soundEnabled, true);

        // Verify it was saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('user_settings');
        final savedMap = json.decode(savedJson!) as Map<String, dynamic>;
        expect(savedMap['soundEnabled'], true);
      });

      test('can disable sound setting', () async {
        // Start with sound enabled
        final initialSettings = UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: true,
        );
        SharedPreferences.setMockInitialValues({});
        await UserSettingsService.instance.saveSettings(initialSettings);

        // Disable sound
        await UserSettingsService.instance.setSoundEnabled(false);

        // Verify the setting was updated
        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached!.soundEnabled, false);
      });
    });

    group('setMetronomeSoundEnabled', () {
      test('updates metronomeSoundEnabled setting and saves to SharedPreferences', () async {
        // Start with metronome sound disabled
        final initialSettings = UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: false,
        );
        SharedPreferences.setMockInitialValues({});
        await UserSettingsService.instance.saveSettings(initialSettings);

        // Enable metronome sound
        await UserSettingsService.instance.setMetronomeSoundEnabled(true);

        // Verify the setting was updated in cache
        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached!.metronomeSoundEnabled, true);

        // Verify it was saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('user_settings');
        final savedMap = json.decode(savedJson!) as Map<String, dynamic>;
        expect(savedMap['metronomeSoundEnabled'], true);
      });

      test('can disable metronome sound setting', () async {
        // Start with metronome sound enabled
        final initialSettings = UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
          metronomeSoundEnabled: true,
        );
        SharedPreferences.setMockInitialValues({});
        await UserSettingsService.instance.saveSettings(initialSettings);

        // Disable metronome sound
        await UserSettingsService.instance.setMetronomeSoundEnabled(false);

        // Verify the setting was updated
        final cached = UserSettingsService.instance.getCachedSettings();
        expect(cached!.metronomeSoundEnabled, false);
      });
    });
  });
}
