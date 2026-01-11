// Audio Settings Data Transfer Object
class AudioSettings {
  final double masterVolume; // 0.0 - 1.0
  final double musicVolume; // 0.0 - 1.0
  final double sfxVolume; // 0.0 - 1.0
  final double voiceVolume; // 0.0 - 1.0
  final bool isMusicEnabled;
  final bool isSfxEnabled;
  final bool isVoiceEnabled;
  final bool isHapticEnabled;
  final int sfxVariantIndex; // 1-4

  const AudioSettings({
    required this.masterVolume,
    required this.musicVolume,
    required this.sfxVolume,
    required this.voiceVolume,
    required this.isMusicEnabled,
    required this.isSfxEnabled,
    required this.isVoiceEnabled,
    required this.isHapticEnabled,
    this.sfxVariantIndex = 1,
  });
}

enum HapticType {
  light, // Card slide
  medium, // Card drop / Button tap
  heavy, // Bluff / Challenge
  success, // Win
  error, // Error / Invalid move
}

abstract class AudioService {
  /// Check if the audio service is initialized
  bool get isInitialized;

  /// Initialize the audio engine (preload sounds, set volume)
  Future<void> initialize();

  /// Play background music (looped)
  /// [path] relative to assets/audio/music/
  Future<void> playBgm(String filename);

  /// Stop background music
  Future<void> stopBgm();

  /// Pause/Resume BGM (e.g. app backgrounding)
  Future<void> pauseBgm();
  Future<void> resumeBgm();

  /// Play a sound effect (one-shot)
  /// [path] relative to assets/audio/sfx/
  Future<void> playSfx(String filename);

  /// Update all volumes based on settings (Master * Channel)
  Future<void> updateVolumes(AudioSettings settings);

  /// "Duck" audio (lower volume) when voice chat is active
  Future<void> duckAudio(bool isVoiceActive);

  /// Trigger haptic feedback
  Future<void> triggerHaptic(HapticType type);

  /// Dispose resources
  Future<void> dispose();
}
