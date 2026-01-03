import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Singleton service for playing sounds throughout the application.
class SoundService {
  static SoundService? _instance;
  late AudioPlayer _audioPlayer;

  SoundService._internal() {
    _audioPlayer = AudioPlayer();
    _configureAudioContext();
  }

  void _configureAudioContext() {
    _audioPlayer.setAudioContext(
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
    _audioPlayer = audioPlayer;
  }

  /// Plays a sound from the assets directory.
  ///
  /// [soundPath] should be relative to the assets directory, e.g., 'sounds/beep.wav'
  Future<void> playSound(String soundPath) async {
    try {
      await _audioPlayer.play(AssetSource(soundPath));
      debugPrint('🔔 Played sound: $soundPath');
    } catch (e) {
      debugPrint('🔔 Failed to play sound ($soundPath): $e');
    }
  }

  /// Disposes the audio player resource.
  void dispose() {
    _audioPlayer.dispose();
    _instance = null;
  }
}
