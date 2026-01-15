/// Constants used in Session/Game logic to avoid magic strings.
class SessionIds {
  SessionIds._();

  /// The local player's ID used in state
  static const me = 'me';

  /// The central pile area
  static const pile = 'pile';

  /// The staging/selected cards area
  static const staging = 'staging';

  /// Offscreen target for scatter animations
  static const offscreen = 'offscreen';
}

/// Duration constants for session animations and timers.
class SessionDurations {
  SessionDurations._();

  /// How long the turn popup displays
  static const turnPopupDuration = Duration(milliseconds: 1500);

  /// Flying card animation duration
  static const cardFlightDuration = Duration(milliseconds: 700);

  /// Card removal cleanup delay
  static const cardCleanupDelay = Duration(milliseconds: 800);

  /// Entry animation duration
  static const entryAnimationDuration = Duration(milliseconds: 1200);

  /// Minimum popup display time before replacement
  static const minPopupDisplayTime = Duration(milliseconds: 600);
}
