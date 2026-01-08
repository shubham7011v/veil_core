class SoundAssets {
  // NOTE: SFX files below require 4 variants in assets/audio/sfx/ (e.g. card_flip_1.wav to _4.wav)
  // Music files are static and do not use variants.
  // The AudioService automatically appends the suffix for SFX based on user settings.

  // --- Music ---
  static const String lobbyAmbience = 'main_bgm.mp3';
  static const String gameBgm = 'main_bgm.mp3';

  // --- SFX: Core Game ---
  static const String cardFlip = 'card_flip.wav';
  static const String cardSlide = 'card_slide.wav';
  static const String chipPlace = 'chip_place.wav';
  static const String dealCard = 'deal_card.wav';

  // --- SFX: Actions ---
  static const String buttonTap = 'button_tap.wav';
  static const String toggleOn = 'toggle_on.wav';
  static const String toggleOff = 'toggle_off.wav';
  static const String error = 'error.wav';
  static const String success = 'success.wav';

  // --- SFX: Game Events ---
  static const String turnAlert = 'turn_alert.wav'; // "Your turn"
  static const String challenge = 'challenge.wav'; // "I doubt it!"
  static const String winRound = 'win_round.wav';
  static const String loseRound = 'lose_round.wav';
  static const String bluffCaught = 'bluff_caught.wav';
}
