class UserSettings {
  final int cyclingFtp;
  final String rowingFtp;
  final bool developerMode;
  final bool soundEnabled;
  final bool metronomeSoundEnabled;

  const UserSettings({
    required this.cyclingFtp,
    required this.rowingFtp,
    required this.developerMode,
    required this.soundEnabled,
    this.metronomeSoundEnabled = true,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      cyclingFtp: json['cyclingFtp'] as int,
      rowingFtp: json['rowingFtp'] as String,
      developerMode: json['developerMode'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      metronomeSoundEnabled: json['metronomeSoundEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cyclingFtp': cyclingFtp,
      'rowingFtp': rowingFtp,
      'developerMode': developerMode,
      'soundEnabled': soundEnabled,
      'metronomeSoundEnabled': metronomeSoundEnabled,
    };
  }

  /// Get the value of a user setting by its name
  /// Returns the setting value in its appropriate format (parsed if necessary)
  dynamic getSettingValue(String settingName) {
    switch (settingName) {
      case 'cyclingFtp':
        return cyclingFtp;
      case 'rowingFtp':
        // Parse rowing FTP if it's a string representation
        if (rowingFtp.contains(':')) {
          // Parse mm:ss format to seconds
          final parts = rowingFtp.split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }
        return double.tryParse(rowingFtp);
      case 'developerMode':
        return developerMode;
      case 'soundEnabled':
        return soundEnabled;
      case 'metronomeSoundEnabled':
        return metronomeSoundEnabled;
      default:
        return null;
    }
  }
}
