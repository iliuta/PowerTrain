import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper to patch UserSettings to allow custom asset path for tests
class TestableUserSettings extends UserSettings {
  const TestableUserSettings({
    required super.cyclingFtp,
    required super.rowingFtp,
    required super.developerMode,
  });

  static Future<UserSettings> loadFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return UserSettings.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Failed to load user settings from $assetPath: $e');
    }
  }
}

void main() {
  const channel = MethodChannel('flutter/assets');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset any previous handler before each test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channel.name, null);
    // Reset SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    // Clean up after each test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channel.name, null);
  });

  group('UserSettings', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'cyclingFtp': 220,
        'rowingFtp': '1:55',
      };
      final settings = UserSettings.fromJson(json);
      expect(settings.cyclingFtp, 220);
      expect(settings.rowingFtp, '1:55');
    });

    test('fromJson throws if required fields are missing', () {
      expect(() => UserSettings.fromJson({}), throwsA(isA<TypeError>()));
      expect(() => UserSettings.fromJson({'cyclingFtp': 220}), throwsA(isA<TypeError>()));
      expect(() => UserSettings.fromJson({'rowingFtp': '2:00'}), throwsA(isA<TypeError>()));
    });

    test('loadFromAsset loads settings from asset (unique path)', () async {
      final assetPath = 'lib/config/default_user_settings_test.json';
      final defaultJson = jsonEncode({
        'cyclingFtp': 250,
        'rowingFtp': '2:00',
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        channel.name,
        (ByteData? message) async {
          final requested = utf8.decode(message!.buffer.asUint8List());
          if (requested == assetPath) {
            return ByteData.view(Uint8List.fromList(defaultJson.codeUnits).buffer);
          }
          return null;
        },
      );
      final settings = await TestableUserSettings.loadFromAsset(assetPath);
      expect(settings.cyclingFtp, 250);
      expect(settings.rowingFtp, '2:00');
    });

    test('loadFromAsset throws if asset is missing (unique path)', () async {
      final assetPath = 'lib/config/missing_user_settings_test.json';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        channel.name,
        (ByteData? message) async => null,
      );
      expect(
        () async => await TestableUserSettings.loadFromAsset(assetPath),
        throwsA(isA<Exception>()),
      );
    });

    test('loadFromAsset throws if asset is invalid JSON (unique path)', () async {
      final assetPath = 'lib/config/invalid_user_settings_test.json';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        channel.name,
        (ByteData? message) async {
          final requested = utf8.decode(message!.buffer.asUint8List());
          if (requested == assetPath) {
            return ByteData.view(Uint8List.fromList('not a json'.codeUnits).buffer);
          }
          return null;
        },
      );
      expect(
        () async => await TestableUserSettings.loadFromAsset(assetPath),
        throwsA(isA<Exception>()),
      );
    });

    group('loadDefault', () {
      const defaultAssetPath = 'lib/config/default_user_settings.json';

      test('loads settings from default asset', () async {
        final defaultJson = jsonEncode({
          'cyclingFtp': 300,
          'rowingFtp': '2:10',
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
          channel.name,
          (ByteData? message) async {
            final requested = utf8.decode(message!.buffer.asUint8List());
            if (requested == defaultAssetPath) {
              return ByteData.view(Uint8List.fromList(defaultJson.codeUnits).buffer);
            }
            return null;
          },
        );
        final settings = await UserSettings.loadDefault();
        expect(settings.cyclingFtp, 300);
        expect(settings.rowingFtp, '2:10');
      });

      test('loads settings from SharedPreferences when available', () async {
        final settingsJson = jsonEncode({
          'cyclingFtp': 250,
          'rowingFtp': '2:00',
          'developerMode': true,
        });
        
        // Set up mock SharedPreferences
        SharedPreferences.setMockInitialValues({'user_settings': settingsJson});
        
        final settings = await UserSettings.loadDefault();
        expect(settings.cyclingFtp, 250);
        expect(settings.rowingFtp, '2:00');
        expect(settings.developerMode, true);
      });

      test('falls back to asset when SharedPreferences fails', () async {
        // Set up empty SharedPreferences (no saved settings)
        SharedPreferences.setMockInitialValues({});
        
        final settings = await UserSettings.loadDefault();
        // Should fall back to asset which contains cyclingFtp: 300, rowingFtp: "2:10"
        expect(settings.cyclingFtp, 300);
        expect(settings.rowingFtp, '2:10');
        expect(settings.developerMode, false);
      });

      test('falls back to asset when SharedPreferences is empty', () async {
        // Set up empty SharedPreferences
        SharedPreferences.setMockInitialValues({});
        
        final settings = await UserSettings.loadDefault();
        // Should fall back to asset which contains cyclingFtp: 300, rowingFtp: "2:10"
        expect(settings.cyclingFtp, 300);
        expect(settings.rowingFtp, '2:10');
        expect(settings.developerMode, false);
      });
    });

    test('toJson converts settings to JSON map', () {
      final settings = UserSettings(
        cyclingFtp: 220,
        rowingFtp: '1:55',
        developerMode: true,
      );

      final json = settings.toJson();

      expect(json, {
        'cyclingFtp': 220,
        'rowingFtp': '1:55',
        'developerMode': true,
      });
    });

    test('save stores settings to SharedPreferences', () async {
      final settings = UserSettings(
        cyclingFtp: 180,
        rowingFtp: '1:45',
        developerMode: false,
      );

      SharedPreferences.setMockInitialValues({});
      await settings.save();

      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('user_settings');
      expect(savedJson, isNotNull);

      final savedMap = json.decode(savedJson!) as Map<String, dynamic>;
      expect(savedMap['cyclingFtp'], 180);
      expect(savedMap['rowingFtp'], '1:45');
      expect(savedMap['developerMode'], false);
    });

    group('getSettingValue', () {
      final settings = UserSettings(
        cyclingFtp: 200,
        rowingFtp: '2:00',
        developerMode: true,
      );

      test('returns cyclingFtp as int', () {
        expect(settings.getSettingValue('cyclingFtp'), 200);
      });

      test('returns rowingFtp as seconds when in mm:ss format', () {
        expect(settings.getSettingValue('rowingFtp'), 120); // 2:00 = 120 seconds
      });

      test('returns rowingFtp as double when numeric string', () {
        final settingsWithNumeric = UserSettings(
          cyclingFtp: 200,
          rowingFtp: '120.5',
          developerMode: false,
        );
        expect(settingsWithNumeric.getSettingValue('rowingFtp'), 120.5);
      });

      test('returns developerMode as bool', () {
        expect(settings.getSettingValue('developerMode'), true);
      });

      test('returns null for unknown setting name', () {
        expect(settings.getSettingValue('unknownSetting'), null);
      });
    });
  });
}
