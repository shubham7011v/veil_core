package game

import (
	"os"
	"strconv"
)

type Phase string

const (
	PhaseLobby       Phase = "lobby"
	PhaseStarting    Phase = "starting"    // 10s countdown window
	PhaseThinking    Phase = "thinking"    // Active player is choosing cards
	PhaseChallenging Phase = "challenging" // Cards played, others deciding to challenge/pass
	PhaseRevealing   Phase = "revealing"   // Waiting for bluff reveal animation
	PhaseFinished    Phase = "finished"
)

type Personality string

const (
	PersonalityConservative Personality = "conservative"
	PersonalityAggressive   Personality = "aggressive"
	PersonalityBalanced     Personality = "balanced"
	PersonalityGhost        Personality = "ghost"
)

// Config
var (
	MaxPlayers = 10
	MinPlayers = 2 // For testing
)

// GetStartGameDelay returns the countdown duration in seconds (dynamic for testing)
func GetStartGameDelay() int {
	if val := os.Getenv("START_GAME_DELAY"); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return 10 // Default
}

func init() {
	if val := os.Getenv("MAX_PLAYERS"); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			MaxPlayers = i
		}
	}
}
