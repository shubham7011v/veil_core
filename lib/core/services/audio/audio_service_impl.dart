import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'audio_service_interface.dart';

import 'package:flutter/foundation.dart';

class AudioServiceImpl implements AudioService {
  // --- Players ---
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer(); // For simple SFX (shared)
  // Note: For overlapping SFX, AudioPlayers supports "Low Latency" mode or multiple instances.
  // For this implementation, we'll use AudioCache implicitly via AssetSource which handles some caching.
  // Ideally, for high-frequency concurrent SFX, we might need a pool, but let's start simple.

  // --- State ---
  AudioSettings? _currentSettings;
  bool _isDucked = false;
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
    // Set Audio Context (keep playing if possible, or respect silent mode)
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
          category: AVAudioSessionCategory
              .ambient, // Mix with other apps? Or playback?
          // playback usually stops other apps. ambient mixes but silences on mute switch.
          // User requested "Respect system silent mode" -> 'ambient' or 'soloAmbient'
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );

    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  Future<void> playBgm(String filename) async {
    _currentBgmFile = filename;
    _isPlayingBgm = true;

    if (_currentSettings != null && !_currentSettings!.isMusicEnabled) {
      return; // Don't play if disabled, but store intent
    }

    try {
      debugPrint('Playing BGM: $_currentBgmFile');
      await _bgmPlayer.play(AssetSource('$_musicPath$filename'));
      await _updateBgmVolume();
    } catch (e) {
      // debugPrint('Error playing BGM: $e');
    }
  }

  @override
  Future<void> stopBgm() async {
    _isPlayingBgm = false;
    await _bgmPlayer.stop();
  }

  @override
  Future<void> pauseBgm() async {
    if (_isPlayingBgm) {
      await _bgmPlayer.pause();
    }
  }

  @override
  Future<void> resumeBgm() async {
    if (_isPlayingBgm) {
      // Only resume if we were conceptually playing
      if (_currentSettings != null && _currentSettings!.isMusicEnabled) {
        await _bgmPlayer.resume();
      }
    }
  }

  @override
  Future<void> playSfx(String filename) async {
    if (_currentSettings != null && !_currentSettings!.isSfxEnabled) {
      return;
    }

    // For overlapping sounds, creating a temporary player is safer than reusing one,
    // though heavier. AudioPlayers 'play' creates a new player if using static AudioPlayer.play?
    // No, instance method.
    // Best practice for low-latency UI SFX is usually creating a new player or using a pool.
    // AudioPlayers 6.0: "AudioPlayer.play" is for playing.
    // To allow overlap:
    final player = AudioPlayer();

    // Auto-dispose player after completion
    player.onPlayerComplete.listen((event) {
      player.dispose();
    });

    // Calculate volume
    double vol = _currentSettings?.masterVolume ?? 1.0;
    vol *= _currentSettings?.sfxVolume ?? 1.0;
    if (_isDucked) vol *= _duckSfxMultiplier;

    await player.setVolume(vol.clamp(0.0, 1.0));
    await player.play(
      AssetSource('$_sfxPath$filename'),
      mode: PlayerMode.lowLatency,
    );
  }

  @override
  Future<void> updateVolumes(AudioSettings settings) async {
    _currentSettings = settings;
    await _updateBgmVolume();

    // SFX volume is applied at play-time for new sounds.
    // Active SFX won't change volume, which is fine for short sounds.
  }

  Future<void> _updateBgmVolume() async {
    if (_currentSettings == null) return;

    if (!_currentSettings!.isMusicEnabled) {
      await _bgmPlayer.setVolume(0);
      // _bgmPlayer.pause(); // Optional: pause to save CPU? or just fade?
      // User might toggle ON/OFF quickly, zero volume is safer flow.
      return;
    }

    // Resume if it was supposed to be playing but was silenced/stopped
    if (_isPlayingBgm && _bgmPlayer.state != PlayerState.playing) {
      // Unless paused by app lifecycle
      // This logic can be tricky. Let's assume playBgm handles start.
      // If we are "playing" but player is stopped/paused ONLY due to mute, resume.
      // But simpler: just set volume.
    }

    double vol = _currentSettings!.masterVolume * _currentSettings!.musicVolume;
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
    if (_currentSettings != null && !_currentSettings!.isHapticEnabled) return;

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
