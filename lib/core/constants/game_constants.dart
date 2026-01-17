/// Game-specific constants for animations, timeouts, and layout values.
///
/// These constants define the timing and behavior of game UI elements.
class GameConstants {
  GameConstants._(); // Private constructor to prevent instantiation

  // ==================== Animation Durations ====================

  /// Standard animation duration for UI transitions
  static const Duration standardAnimationDuration = Duration(milliseconds: 300);

  /// Fast animation for quick feedback
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);

  /// Slow animation for dramatic effects
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  /// Matchmaking orbit animation duration
  static const Duration matchmakingOrbitDuration = Duration(seconds: 4);

  /// Pulse animation duration for attention
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1500);

  /// Card flip animation
  static const Duration cardFlipDuration = Duration(milliseconds: 400);

  /// Challenge reveal animation
  static const Duration challengeRevealDuration = Duration(milliseconds: 800);

  // ==================== Timeouts ====================

  /// Matchmaking timeout before auto-filling with bots (seconds)
  static const int matchmakingTimeoutSeconds = 45;

  /// Warning threshold for matchmaking timeout (seconds)
  static const int matchmakingWarningSeconds = 15;

  /// Turn timeout for players (seconds)
  static const int turnTimeoutSeconds = 30;

  /// Reconnection timeout (seconds)
  static const int reconnectionTimeoutSeconds = 60;

  // ==================== Layout ====================

  /// Maximum number of players in a game
  static const int maxPlayers = 5;

  /// Default grid cross-axis count for player cards
  static const int playerGridCrossAxisCount = 3;

  /// Player card aspect ratio
  static const double playerCardAspectRatio = 0.68;

  /// Card width in pixels
  static const double cardWidth = 100.0;

  /// Card height in pixels
  static const double cardHeight = 140.0;

  /// Avatar size
  static const double avatarSize = 48.0;

  /// Large avatar size
  static const double avatarSizeLarge = 80.0;

  // ==================== Game Logic ====================

  /// Minimum cards that can be played in a turn
  static const int minCardsPerPlay = 1;

  /// Maximum cards that can be played in a turn
  static const int maxCardsPerPlay = 4;

  /// Default boot amount for public games
  static const int defaultBootAmount = 100;

  /// Deck size (standard 52-card deck)
  static const int deckSize = 52;

  // ==================== UI Constants ====================

  /// Opacity for disabled states
  static const double disabledOpacity = 0.5;

  /// Opacity for semi-transparent overlays
  static const double overlayOpacity = 0.8;

  /// Z-index for floating elements
  static const int floatingZIndex = 100;

  /// Icon size for action buttons
  static const double actionIconSize = 24.0;

  /// Large icon size
  static const double largeIconSize = 48.0;
}
