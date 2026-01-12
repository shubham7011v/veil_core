package db

// UserDatabase defines the interface for database operations
// This allows for dependency injection and easier testing with mock implementations
type UserDatabase interface {
	// User Management
	GetOrCreateUser(userID string, name string) (*UserStats, error)
	DeleteUser(userID string) error
	BanUser(userID string) error

	// User Stats
	UpdateUserCoins(userID string, amount int) error
	UpdateUserName(userID, newName string) error
	UpdateUserAvatar(userID, newAvatar string) error
	RecordGameResult(matchID string, playerIDs []string, winnerID string, durationSec int, potAmount int) error
	GetLeaderboard() ([]UserStats, error)

	// Friends
	AddFriend(userID, friendID string) error
	AcceptFriend(userID, friendID string) error
	GetFriends(userID string) ([]FriendRecord, error)

	// Daily Challenges
	GetDailyChallengesStatus(userID string) ([]map[string]interface{}, error)
	UpdateChallengeProgress(userID string, challengeType string, delta int) error
	ClaimChallengeReward(userID string, challengeID string) (int, error)
	ResetDailyChallenges() error

	// Coin Buffer Operations
	BufferCoinUpdate(userID string, amount int)
	FlushCoins() error
}

// DatabaseService is the concrete implementation of UserDatabase
// The existing code uses package-level functions, so we'll create a wrapper struct
type DatabaseService struct{}

// NewDatabaseService creates a new database service instance
func NewDatabaseService() *DatabaseService {
	return &DatabaseService{}
}

// Implement all interface methods by delegating to package-level functions

func (d *DatabaseService) GetOrCreateUser(userID string, name string) (*UserStats, error) {
	return GetOrCreateUser(userID, name)
}

func (d *DatabaseService) DeleteUser(userID string) error {
	return DeleteUser(userID)
}

func (d *DatabaseService) BanUser(userID string) error {
	return BanUser(userID)
}

func (d *DatabaseService) UpdateUserCoins(userID string, amount int) error {
	return UpdateUserCoins(userID, amount)
}

func (d *DatabaseService) UpdateUserName(userID, newName string) error {
	return UpdateUserName(userID, newName)
}

func (d *DatabaseService) UpdateUserAvatar(userID, newAvatar string) error {
	return UpdateUserAvatar(userID, newAvatar)
}

func (d *DatabaseService) RecordGameResult(matchID string, playerIDs []string, winnerID string, durationSec int, potAmount int) error {
	return RecordGameResult(matchID, playerIDs, winnerID, durationSec, potAmount)
}

func (d *DatabaseService) GetLeaderboard() ([]UserStats, error) {
	return GetLeaderboard()
}

func (d *DatabaseService) AddFriend(userID, friendID string) error {
	return AddFriend(userID, friendID)
}

func (d *DatabaseService) AcceptFriend(userID, friendID string) error {
	return AcceptFriend(userID, friendID)
}

func (d *DatabaseService) GetFriends(userID string) ([]FriendRecord, error) {
	return GetFriends(userID)
}

func (d *DatabaseService) GetDailyChallengesStatus(userID string) ([]map[string]interface{}, error) {
	return GetDailyChallengesStatus(userID)
}

func (d *DatabaseService) UpdateChallengeProgress(userID string, challengeType string, delta int) error {
	return UpdateChallengeProgress(userID, challengeType, delta)
}

func (d *DatabaseService) ClaimChallengeReward(userID string, challengeID string) (int, error) {
	return ClaimChallengeReward(userID, challengeID)
}

func (d *DatabaseService) ResetDailyChallenges() error {
	return ResetDailyChallenges()
}

func (d *DatabaseService) BufferCoinUpdate(userID string, amount int) {
	BufferCoinUpdate(userID, amount)
}

func (d *DatabaseService) FlushCoins() error {
	return FlushCoins()
}
