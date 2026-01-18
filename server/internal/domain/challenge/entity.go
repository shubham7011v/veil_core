package challenge

import "time"

// Challenge represents a daily task definition
type Challenge struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Goal        int    `json:"goal"`
	Reward      int    `json:"reward"`
	Type        string `json:"type"` // e.g., 'wins', 'games_played', 'coins_won'
}

// UserProgress represents a user's progress on a specific challenge
type UserProgress struct {
	ChallengeID string    `json:"challengeId"`
	UserID      string    `json:"userId"`
	Current     int       `json:"current"`
	IsClaimed   bool      `json:"isClaimed"`
	Completed   bool      `json:"completed"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// ChallengeWithProgress is a composite view for the client
type ChallengeWithProgress struct {
	Challenge
	Current   int  `json:"current"`
	IsClaimed bool `json:"isClaimed"`
	Completed bool `json:"completed"`
}
