package match

import "time"

type MatchResult struct {
	MatchID     string         `json:"matchId"`
	CreatedAt   time.Time      `json:"createdAt"`
	EndedAt     time.Time      `json:"endedAt"`
	PlayerIDs   []string       `json:"playerIds"`
	WinnerID    string         `json:"winnerId"`
	DurationSec int            `json:"durationSec"`
	PotAmount   int            `json:"potAmount"`
	Metadata    map[string]any `json:"metadata"` // Stores detailed stats (bluffs, calls, etc.)
}
