package game

type Phase string

const (
	PhaseLobby       Phase = "lobby"
	PhaseThinking    Phase = "thinking" // Active player is choosing cards
	PhaseChallenging Phase = "challenging" // Cards played, others deciding to challenge/pass
	PhaseFinished    Phase = "finished"
)

// Config
const (
	MaxPlayers = 6
	MinPlayers = 2 // For testing
)
