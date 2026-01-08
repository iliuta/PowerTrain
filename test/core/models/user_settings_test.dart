import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/settings/model/user_settings.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('toJson converts settings to JSON map', () {
      final settings = UserSettings(
        cyclingFtp: 220,
        rowingFtp: '1:55',
        developerMode: true,
        soundEnabled: false,
      );

      final json = settings.toJson();

      expect(json, {
        'cyclingFtp': 220,
        'rowingFtp': '1:55',
        'developerMode': true,
        'soundEnabled': false,
        'metronomeSoundEnabled': true
      });
    });

    group('getSettingValue', () {
      final settings = UserSettings(
        cyclingFtp: 200,
        rowingFtp: '2:00',
        developerMode: true,
        soundEnabled: false,
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
          soundEnabled: true,
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
