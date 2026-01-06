enum BotPersonality { conservative, aggressive, balanced, ghost }

enum SessionEventType {
  none,
  turnChanged,
  cardsPlayed,
  passed,
  bluffCalled,
  bluffRevealed,
  cardsDealt,
  cardsPickedUp,
  pileDiscarded,
  cardStaged,
  shuffling,
  connectionFailed,
}
