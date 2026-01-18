package user

// Repository defines the interface for persisting generic user data
type Repository interface {
	// GetOrCreate fetches a user or creates one if missing
	GetOrCreate(id, name string) (*User, error)

	// UpdateCoins updates the coin balance (transactional)
	UpdateCoins(id string, amount int) error

	// UpdateProfile updates name or avatar
	UpdateProfile(id, name, avatar string) error

	// GetLeaderboard returns the top N users
	GetLeaderboard(limit int) ([]User, error)

	// GetMatchHistory returns recent matches
	GetMatchHistory(userID string, limit int) ([]MatchHistoryItem, error)

	// BanUser bans a user
	BanUser(id string) error

	// DeleteUser deletes all user data
	DeleteUser(id string) error
}
