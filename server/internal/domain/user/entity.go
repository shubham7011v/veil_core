package user

import "time"

// User represents the player in the domain layer
type User struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	AvatarURL   string    `json:"avatarUrl"`
	Rank        string    `json:"rank"`
	Rating      int       `json:"rating"` // Elo or similar
	Coins       int       `json:"coins"`
	GamesPlayed int       `json:"gamesPlayed"`
	Wins        int       `json:"wins"`
	Losses      int       `json:"losses"`
	IsBanned    bool      `json:"isBanned"`
	LastSeen    time.Time `json:"lastSeen"`
}

// CalculateRank updates the rank based on wins (Business Logic)
// This logic was previously in database.go, moving it to Domain (Entity Logic)
func (u *User) CalculateRank() {
	switch {
	case u.Wins < 5:
		u.Rank = "Novice"
	case u.Wins < 20:
		u.Rank = "Apprentice"
	case u.Wins < 50:
		u.Rank = "Adept"
	case u.Wins < 100:
		u.Rank = "Expert"
	case u.Wins < 200:
		u.Rank = "Master"
	default:
		u.Rank = "Legend"
	}
}

type MatchHistoryItem struct {
	MatchID   string    `json:"matchId"`
	CreatedAt time.Time `json:"createdAt"`
	EndedAt   time.Time `json:"endedAt"`
	PlayerIDs []string  `json:"playerIds"`
	WinnerID  string    `json:"winnerId"`
}
