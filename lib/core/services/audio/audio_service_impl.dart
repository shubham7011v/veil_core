import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'audio_service_interface.dart';
import '../../di/service_locator.dart';

class AudioServiceImpl implements AudioService {
  // --- Players ---
  // --- Players ---
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer(); // For simple SFX (shared)
  final AudioCache _audioCache = AudioCache(prefix: 'assets/$_sfxPath');
  // Note: For overlapping SFX, AudioPlayers supports "Low Latency" mode or multiple instances.
  // For this implementation, we'll use AudioCache to pre-load freq used sounds.

  // --- State ---
  AudioSettings _currentSettings = const AudioSettings(
    masterVolume: 0.75,
    musicVolume: 0.35,
    sfxVolume: 0.70,
    voiceVolume: 0.85,
    isMusicEnabled: true,
    isSfxEnabled: true,
    isVoiceEnabled: true,
    isHapticEnabled: true,
    sfxVariantIndex: 1,
  );
  bool _isDucked = false;
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  String? _currentBgmFile;
  bool _isPlayingBgm = false;

  // --- Constants ---
  static const String _musicPath = 'audio/music/';
  static const String _sfxPath = 'audio/sfx/';

  // Ducking multipliers
  static const double _duckBgmMultiplier = 0.1;
  static const double _duckSfxMultiplier = 0.3;

  @override
  Future<void> initialize() async {
    try {
      // Set Audio Context
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {},
          ),
        ),
      );

      _bgmPlayer.setReleaseMode(ReleaseMode.loop);

      // Pre-cache frequently used sound effects
      await _preCacheSounds();

      // Load initial settings from storage
      _loadInitialSettings();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioService initialization failed: $e');
      // We don't rethrow here to allow app to proceed without audio
    }
  }

  Future<void> _preCacheSounds() async {
    final soundsToCache = <String>[];

    // Critical SFX list
    const criticalSfx = [
      'card_slide',
      'deal_card',
      'turn_alert',
      'button_tap',
      'chip_place',
    ];

    for (final sfx in criticalSfx) {
      for (int i = 1; i <= 4; i++) {
        soundsToCache.add('${sfx}_$i.wav');
      }
    }

    try {
      await _audioCache.loadAll(soundsToCache);
      debugPrint('Pre-cached ${soundsToCache.length} sound assets');
    } catch (e) {
      debugPrint('Failed to pre-cache sounds: $e');
    }
  }

  void _loadInitialSettings() {
    try {
      final storage = sl.storageService;
      _currentSettings = AudioSettings(
        masterVolume: (storage.getInt('pref_master_volume') ?? 75) / 100,
        voiceVolume: (storage.getInt('pref_voice_volume') ?? 85) / 100,
        musicVolume: (storage.getInt('pref_music_volume') ?? 35) / 100,
        sfxVolume: (storage.getInt('pref_sfx_volume') ?? 70) / 100,
        isMusicEnabled: storage.getBool('pref_music') ?? true,
        isSfxEnabled: storage.getBool('pref_sfx') ?? true,
        isVoiceEnabled: storage.getBool('pref_voice') ?? true,
        isHapticEnabled: storage.getBool('pref_haptics') ?? true,
        sfxVariantIndex: storage.getInt('pref_sfx_variant') ?? 1,
      );
      debugPrint('Audio settings loaded from storage');
    } catch (e) {
      debugPrint('Error loading audio settings: $e');
    }
  }

  @override
  Future<void> playBgm(String filename) async {
    if (_currentBgmFile == filename &&
        _bgmPlayer.state == PlayerState.playing) {
      return;
    }

    _currentBgmFile = filename;
    _isPlayingBgm = true;

    if (!_currentSettings.isMusicEnabled) {
      return; // Don't play if disabled, but store intent
    }

    try {
      debugPrint('Playing BGM: filename=$filename');
      await _bgmPlayer.play(AssetSource('$_musicPath$filename'));
      await _updateBgmVolume();
    } catch (e, stackTrace) {
      debugPrint('Error playing BGM: $e');
      debugPrint('Stack trace: $stackTrace');
      _isPlayingBgm = false; // Graceful degradation
    }
  }

  String _resolveFilename(String filename, int variantIndex) {
    if (filename.isEmpty) return '';

    // SFX files are expected to have variants like 'filename_1.wav'
    // This method splits the extension and appends the variant index.
    final lastDot = filename.lastIndexOf('.');

    if (lastDot == -1) {
      return '${filename}_$variantIndex';
    }

    final name = filename.substring(0, lastDot);
    final ext = filename.substring(lastDot);

    // Prevent double suffixing if the filename already has the index
    if (name.endsWith('_$variantIndex')) {
      return filename;
    }

    return '${name}_$variantIndex$ext';
  }

  @override
  Future<void> stopBgm() async {
    _isPlayingBgm = false;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping BGM: $e');
    }
  }

  @override
  Future<void> pauseBgm() async {
    if (_isPlayingBgm) {
      try {
        await _bgmPlayer.pause();
      } catch (e) {
        debugPrint('Error pausing BGM: $e');
      }
    }
  }

  @override
  Future<void> resumeBgm() async {
    if (_isPlayingBgm) {
      // Only resume if we were conceptually playing
      if (_currentSettings.isMusicEnabled) {
        try {
          await _bgmPlayer.resume();
        } catch (e) {
          debugPrint('Error resuming BGM: $e');
        }
      }
    }
  }

  @override
  Future<void> playSfx(String filename) async {
    if (!_currentSettings.isSfxEnabled) {
      return;
    }

    try {
      final player = AudioPlayer();

      // Auto-dispose player after completion
      player.onPlayerComplete.listen((event) {
        player.dispose();
      });

      // Calculate volume
      double vol = _currentSettings.masterVolume;
      vol *= _currentSettings.sfxVolume;
      if (_isDucked) vol *= _duckSfxMultiplier;

      await player.setVolume(vol.clamp(0.0, 1.0));

      final resolved = _resolveFilename(
        filename,
        _currentSettings.sfxVariantIndex,
      );
      await player.play(
        AssetSource('$_sfxPath$resolved'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e, stackTrace) {
      debugPrint('Error playing SFX: $e');
      debugPrint('Stack trace: $stackTrace');
      // Graceful degradation: continue silently
    }
  }

  @override
  Future<void> playEmojiSound(String emojiId) async {
    // Map categories to sounds
    // Positive/Laugh: chip_place
    // Negative/Angry: error
    // Alert/Surprise: turn_alert
    // Pass/Wait: button_tap

    String sound = 'button_tap';
    if (emojiId.contains('laugh') ||
        emojiId.contains('smile') ||
        emojiId.contains('joy')) {
      sound = 'chip_place';
    } else if (emojiId.contains('angry') ||
        emojiId.contains('sad') ||
        emojiId.contains('cry')) {
      sound = 'error';
    } else if (emojiId.contains('wow') ||
        emojiId.contains('surprise') ||
        emojiId.contains('shock')) {
      sound = 'turn_alert';
    }

    await playSfx('$sound.wav');
  }

  @override
  Future<void> updateVolumes(AudioSettings settings) async {
    _currentSettings = settings;

    // Apply volumes
    await _updateBgmVolume();
  }

  Future<void> _updateBgmVolume() async {
    if (!_currentSettings.isMusicEnabled) {
      // If we are currently playing, stop/pause it?
      // For now just zero volume.
      await _bgmPlayer.setVolume(0);
      return;
    }

    // If we should be playing but are not (e.g. was disabled then enabled)
    if (_isPlayingBgm &&
        _bgmPlayer.state != PlayerState.playing &&
        _currentBgmFile != null) {
      await _bgmPlayer.play(AssetSource('$_musicPath$_currentBgmFile'));
    }

    double vol = _currentSettings.masterVolume * _currentSettings.musicVolume;
    if (_isDucked) vol *= _duckBgmMultiplier;

    await _bgmPlayer.setVolume(vol.clamp(0.0, 1.0));
  }

  @override
  Future<void> duckAudio(bool isVoiceActive) async {
    if (_isDucked == isVoiceActive) return; // No change

    _isDucked = isVoiceActive;

    // Animate volume change?
    // AudioPlayers doesn't have built-in fade (yet), instant for now.
    await _updateBgmVolume();
  }

  @override
  Future<void> triggerHaptic(HapticType type) async {
    if (!_currentSettings.isHapticEnabled) return;

    switch (type) {
      case HapticType.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticType.success:
        await HapticFeedback.vibrate(); // Heavier
        break;
      case HapticType.error:
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.vibrate();
        break;
    }
  }

  @override
  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
