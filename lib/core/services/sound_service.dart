import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'user_settings_service.dart';

/// Singleton service for playing sounds throughout the application.
class SoundService {
  static SoundService? _instance;
  late AudioPlayer _disappointingBeepPlayer;
  late AudioPlayer _beepPlayer;
  late AudioPlayer _tickPlayer;

  SoundService._internal() {
    _disappointingBeepPlayer = AudioPlayer();
    _beepPlayer = AudioPlayer();
    _tickPlayer = AudioPlayer();
    _configureAudioContext(_disappointingBeepPlayer);
    _configureAudioContext(_beepPlayer);
    _configureAudioContext(_tickPlayer);
  }

  void _configureAudioContext(AudioPlayer player) {
    player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioMode: AndroidAudioMode.normal,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
  }

  /// Get the singleton instance of SoundService.
  static SoundService get instance => _instance ??= SoundService._internal();

  /// Initialize SoundService with a custom AudioPlayer (primarily for testing).
  static void initialize(AudioPlayer audioPlayer) {
    _instance = SoundService._createForTesting(audioPlayer);
  }

  SoundService._createForTesting(AudioPlayer audioPlayer) {
    _disappointingBeepPlayer = audioPlayer;
    _beepPlayer = audioPlayer;
    _tickPlayer = audioPlayer;
  }

  Future<void> playDissapointingBeep() async {
    // Get cached settings or load them
    final settings = await UserSettingsService.instance.loadSettings();
    var soundPath = 'sounds/disappointing_beep.wav';

    if (settings.soundEnabled == false) {
      debugPrint('🔔 Sound alerts disabled, skipping sound: $soundPath');
      return;
    }
    playSound(soundPath, _disappointingBeepPlayer);
  }

  Future<void> playTickHigh() async {
    // Get cached settings or load them
    final settings = await UserSettingsService.instance.loadSettings();
    var soundPath = 'sounds/tick_high.wav';

    if (settings.metronomeSoundEnabled == false) {
      debugPrint('🔔 Metronome sound disabled, skipping sound: $soundPath');
      return;
    }
    playSound(soundPath, _tickPlayer);
  }

  Future<void> playTickLow() async {
    // Get cached settings or load them
    final settings = await UserSettingsService.instance.loadSettings();
    var soundPath = 'sounds/tick_low.wav';

    if (settings.metronomeSoundEnabled == false) {
      debugPrint('🔔 Metronome sound disabled, skipping sound: $soundPath');
      return;
    }
    playSound(soundPath, _tickPlayer);
  }

  Future<void> playBeep() async {
    // Get cached settings or load them
    final settings = await UserSettingsService.instance.loadSettings();
    var soundPath = 'sounds/beep.wav';

    if (settings.soundEnabled == false) {
      debugPrint('🔔 Sound alerts disabled, skipping sound: $soundPath');
      return;
    }
    playSound(soundPath, _beepPlayer);
  }

  /// Plays a sound from the assets directory.
  ///
  /// [soundPath] should be relative to the assets directory, e.g., 'sounds/beep.wav'
  Future<void> playSound(String soundPath, AudioPlayer player) async {
    try {
      await player.play(AssetSource(soundPath));
      debugPrint('🔔 Played sound: $soundPath');
    } catch (e) {
      debugPrint('🔔 Failed to play sound ($soundPath): $e');
    }
  }

  /// Disposes the audio player resource.
  void dispose() {
    _disappointingBeepPlayer.dispose();
    _beepPlayer.dispose();
    _tickPlayer.dispose();
    _instance = null;
  }
}
