// Package game implements the core bluff card game logic and rules.
//
// # Game Overview
//
// This package contains the pure game logic for a bluff-style card game where players
// claim to play cards of a certain rank, and opponents can challenge their claims.
//
// # Core Components
//
//   - Game: Main game state container managing players, phases, and turn progression
//   - Player: Individual participant with a hand of cards and statistics
//   - Card: Deck management with ranks and suits
//   - Phase: Game lifecycle states (Lobby, Starting, Thinking, Challenging, Revealing, Finished)
//   - Logic: Game rules and action validation (PlayCards, Challenge, Pass)
//
// # Game Phases
//
//	PhaseLobby:       Waiting for players to join
//	PhaseStarting:    Countdown before game begins
//	PhaseThinking:    Active player choosing which cards to play
//	PhaseChallenging: Other players decide whether to challenge the last play
//	PhaseRevealing:   Showing the truth after a challenge
//	PhaseFinished:    Game ended with a winner
//
// # Game Rules
//
//   - Players take turns playing 1-4 cards face down
//   - All cards played in a round must be of the same declared rank
//   - Players can bluff by claiming a rank different from their actual cards
//   - Other players can challenge the claim
//   - If the challenge succeeds (bluff caught), the bluffer takes the pile
//   - If the challenge fails (honest claim), the challenger takes the pile
//   - First player to empty their hand wins
//
// # Anti-Cheat
//
// The package includes deck consistency verification to detect card duplication
// or missing cards through the VerifyDeckConsistency method.
//
// # Thread Safety
//
// Game state is NOT thread-safe and should only be accessed by the owning Room's
// goroutine. All synchronization is handled at the Room level.
package game
