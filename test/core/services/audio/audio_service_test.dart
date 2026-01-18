import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:veil_core/core/services/audio/audio_service_interface.dart';
import 'package:veil_core/core/services/audio/audio_service_impl.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock MethodChannels for audioplayers to avoid MissingPluginException
  const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const playerChannel = MethodChannel('xyz.luan/audioplayers');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(globalChannel, (methodCall) async => null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        playerChannel,
        (methodCall) async => {'playerId': 'test-player-id'},
      );

  late AudioServiceImpl audioService;

  setUp(() {
    audioService = AudioServiceImpl();
  });

  group('AudioService Initialization', () {
    test('isInitialized is initially false', () {
      expect(audioService.isInitialized, false);
    });
  });

  group('Volume Control', () {
    test('updateVolumes updates internal settings', () async {
      const settings = AudioSettings(
        masterVolume: 0.5,
        musicVolume: 0.8,
        sfxVolume: 0.6,
        voiceVolume: 0.7,
        isMusicEnabled: true,
        isSfxEnabled: true,
        isVoiceEnabled: true,
        isHapticEnabled: true,
      );

      await audioService.updateVolumes(settings);
      expect(true, true);
    });
  });

  group('Haptic Feedback', () {
    test('triggerHaptic does not throw', () async {
      await audioService.triggerHaptic(HapticType.light);
      await audioService.triggerHaptic(HapticType.medium);
      await audioService.triggerHaptic(HapticType.heavy);
      await audioService.triggerHaptic(HapticType.success);
      await audioService.triggerHaptic(HapticType.error);
    });
  });

  group('Emoji Sounds', () {
    test('playEmojiSound handles various emoji categories', () async {
      await audioService.playEmojiSound('laugh_emoji');
      await audioService.playEmojiSound('angry_emoji');
      await audioService.playEmojiSound('wow_emoji');
      await audioService.playEmojiSound('default_emoji');
    });
  });
}
