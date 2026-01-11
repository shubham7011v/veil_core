package game

import (
	"os"
	"strconv"
)

type Phase string

const (
	PhaseLobby       Phase = "lobby"
	PhaseThinking    Phase = "thinking"    // Active player is choosing cards
	PhaseChallenging Phase = "challenging" // Cards played, others deciding to challenge/pass
	PhaseRevealing   Phase = "revealing"   // Waiting for bluff reveal animation
	PhaseFinished    Phase = "finished"
)

// Config
var (
	MaxPlayers = 10
	MinPlayers = 2 // For testing
)

func init() {
	if val := os.Getenv("MAX_PLAYERS"); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			MaxPlayers = i
		}
	}
}
