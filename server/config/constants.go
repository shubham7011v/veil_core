package config

import "time"

// Game timing constants
const (
	// Grace period for disconnected players to reconnect (seconds)
	DefaultGracePeriodSec = 60

	// Delay before starting a game after lobby fills (seconds)
	LobbyStartDelaySec = 15

	// Maximum time allowed per turn (seconds)
	TurnTimeoutSec = 30

	// Bot thinking delay to simulate human behavior (seconds)
	BotThinkingDelaySec = 10

	// Interval for periodic full state sync (seconds)
	PeriodicSyncIntervalSec = 30

	// Animation delay for challenge resolution (seconds)
	ChallengeRevealDelaySec = 2

	// Lobby timeout before auto-filling with bots (seconds)
	LobbyTimeoutSec = 45

	// Matchmaker tick interval (milliseconds)
	MatchmakerTickIntervalMs = 200
)

// Duration constants (pre-calculated for convenience)
var (
	DefaultGracePeriod     = time.Duration(DefaultGracePeriodSec) * time.Second
	LobbyStartDelay        = time.Duration(LobbyStartDelaySec) * time.Second
	TurnTimeout            = time.Duration(TurnTimeoutSec) * time.Second
	BotThinkingDelay       = time.Duration(BotThinkingDelaySec) * time.Second
	PeriodicSyncInterval   = time.Duration(PeriodicSyncIntervalSec) * time.Second
	ChallengeRevealDelay   = time.Duration(ChallengeRevealDelaySec) * time.Second
	LobbyTimeout           = time.Duration(LobbyTimeoutSec) * time.Second
	MatchmakerTickInterval = time.Duration(MatchmakerTickIntervalMs) * time.Millisecond
)

// Room configuration
const (
	// Default maximum players in a room
	DefaultMaxPlayers = 5

	// Minimum players required to start a game
	MinPlayersToStart = 2

	// Maximum players allowed in any room
	AbsoluteMaxPlayers = 10

	// Default boot amount for public rooms
	DefaultBootAmount = 100

	// Channel buffer sizes
	BroadcastChannelBuffer  = 32
	RegisterChannelBuffer   = 10
	UnregisterChannelBuffer = 10
	ActionsChannelBuffer    = 32
)

// Manager configuration
const (
	// Manager channel buffer sizes
	ManagerRegisterBuffer   = 1024
	ManagerUnregisterBuffer = 1024
	SessionExpiryBuffer     = 1024

	// Deadlock detection threshold (seconds)
	DeadlockThresholdSec = 15

	// Manager tick interval (seconds)
	ManagerTickIntervalSec = 1
)
