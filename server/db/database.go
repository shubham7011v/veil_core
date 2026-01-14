package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

var DB *sql.DB

// -- Coin Buffer Implementation --

type CoinBuffer struct {
	mu      sync.Mutex
	updates map[string]int // userID -> amountDelta
}

var coinBuffer = &CoinBuffer{
	updates: make(map[string]int),
}

// BufferCoinUpdate queues a coin update in memory
func BufferCoinUpdate(userID string, amount int) {
	coinBuffer.mu.Lock()
	defer coinBuffer.mu.Unlock()
	coinBuffer.updates[userID] += amount
}

// StartCoinFlusher starts a background goroutine to flush coins every 60s
func StartCoinFlusher() {
	ticker := time.NewTicker(60 * time.Second)
	go func() {
		for range ticker.C {
			if err := FlushCoins(); err != nil {
				log.Printf("Error flushing coins: %v", err)
			}
		}
	}()
}

// StartDailyResetWorker triggers a database cleanup every day at midnight UTC
func StartDailyResetWorker() {
	go func() {
		for {
			now := time.Now().UTC()
			next := now.Add(time.Hour * 24)
			next = time.Date(next.Year(), next.Month(), next.Day(), 0, 0, 0, 0, time.UTC)
			t := time.NewTimer(next.Sub(now))

			log.Printf("Daily Challenge Reset scheduled for %v", next)
			<-t.C

			if err := ResetDailyChallenges(); err != nil {
				log.Printf("CRITICAL: Failed to reset daily challenges: %v", err)
			} else {
				log.Println("SUCCESS: Daily challenges have been reset for all users.")
			}
		}
	}()
}

// FlushCoins writes all buffered coin updates to the DB in a single transaction
func FlushCoins() error {
	coinBuffer.mu.Lock()
	updates := coinBuffer.updates
	coinBuffer.updates = make(map[string]int) // Reset buffer
	coinBuffer.mu.Unlock()

	if len(updates) == 0 {
		return nil
	}

	// Helper to restore updates on failure
	restore := func() {
		coinBuffer.mu.Lock()
		defer coinBuffer.mu.Unlock()
		for uid, amount := range updates {
			coinBuffer.updates[uid] += amount
		}
	}

	tx, err := DB.Begin()
	if err != nil {
		restore()
		return fmt.Errorf("failed to begin transaction: %v", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare("UPDATE users SET coins = coins + ? WHERE user_id = ?")
	if err != nil {
		restore()
		return fmt.Errorf("failed to prepare statement: %v", err)
	}
	defer stmt.Close()

	for uid, amount := range updates {
		if amount == 0 {
			continue
		}
		if _, err := stmt.Exec(amount, uid); err != nil {
			log.Printf("Failed to update coins for user %s: %v", uid, err)
			// We don't restore individual failures here to avoid partial double-counts,
			// but the log will show which user failed.
			// In WAL mode with busy_timeout, this is rare.
		}
	}

	if err := tx.Commit(); err != nil {
		restore()
		return fmt.Errorf("failed to commit transaction: %v", err)
	}

	log.Printf("Successfully flushed coin updates for %d users", len(updates))
	return nil
}

type UserStats struct {
	UserID      string `json:"userId"`
	Name        string `json:"name"`
	GamesPlayed int    `json:"gamesPlayed"`
	Wins        int    `json:"wins"`
	Losses      int    `json:"losses"`
	Rank        string `json:"rank"`
	Coins       int    `json:"coins"`
	AvatarURL   string `json:"avatarUrl"`
}

type DailyChallenge struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Goal        int    `json:"goal"`
	Reward      int    `json:"reward"`
	Type        string `json:"type"` // e.g., 'wins', 'games_played', 'coins_won'
}

type UserChallengeProgress struct {
	ChallengeID string `json:"challengeId"`
	UserID      string `json:"userId"`
	Current     int    `json:"current"`
	IsClaimed   bool   `json:"isClaimed"`
	Completed   bool   `json:"completed"`
}

// InitDB initializes the SQLite database and creates tables
func InitDB(dbPath string) error {
	// Ensure directory exists
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	var err error
	DB, err = sql.Open("sqlite", dbPath)
	if err != nil {
		return err
	}

	if err = DB.Ping(); err != nil {
		return err
	}

	log.Println("Database connected at", dbPath)

	// Enable Write-Ahead Logging (WAL) for concurrency
	if _, err := DB.Exec("PRAGMA journal_mode=WAL;"); err != nil {
		return fmt.Errorf("failed to enable WAL mode: %v", err)
	}
	// Set busy timeout to prevent "database is locked" errors
	if _, err := DB.Exec("PRAGMA busy_timeout=5000;"); err != nil {
		return fmt.Errorf("failed to set busy timeout: %v", err)
	}

	// Start internal background workers
	StartCoinFlusher()
	StartDailyResetWorker()

	return createTables()
}

func createTables() error {
	// Users Table
	queryUsers := `
	CREATE TABLE IF NOT EXISTS users (
		user_id TEXT PRIMARY KEY,
		name TEXT,
		avatar TEXT,
		nickname TEXT,
		games_played INTEGER DEFAULT 0,
		wins INTEGER DEFAULT 0,
		losses INTEGER DEFAULT 0,
		coins INTEGER DEFAULT 1000,
		is_banned BOOLEAN DEFAULT 0,
		last_seen TIMESTAMP
	);`

	// Matches Table
	queryMatches := `
	CREATE TABLE IF NOT EXISTS matches (
		match_id TEXT PRIMARY KEY,
		created_at TIMESTAMP,
		ended_at TIMESTAMP,
		players_json TEXT,
		winner_id TEXT
	);`

	// Friends Table
	queryFriends := `
	CREATE TABLE IF NOT EXISTS friends (
		user_id TEXT,
		friend_id TEXT,
		status TEXT, --- 'pending', 'accepted'
		created_at TIMESTAMP,
		PRIMARY KEY (user_id, friend_id)
	);`

	if _, err := DB.Exec(queryUsers); err != nil {
		return err
	}
	if _, err := DB.Exec(queryMatches); err != nil {
		return err
	}
	if _, err := DB.Exec(queryFriends); err != nil {
		return err
	}

	// Challenges Table
	queryChallenges := `
	CREATE TABLE IF NOT EXISTS challenges (
		id TEXT PRIMARY KEY,
		title TEXT,
		description TEXT,
		goal INTEGER,
		reward INTEGER,
		type TEXT
	);`

	// User Challenges Table (Progress)
	queryUserChallenges := `
	CREATE TABLE IF NOT EXISTS user_challenges (
		user_id TEXT,
		challenge_id TEXT,
		current INTEGER DEFAULT 0,
		is_claimed BOOLEAN DEFAULT 0,
		updated_at TIMESTAMP,
		PRIMARY KEY (user_id, challenge_id)
	);`

	// Migration: Add is_banned if it doesn't exist (SQLite doesn't support IF NOT EXISTS on ALTER TABLE easily)
	// We'll just try to add it and ignore error if it exists
	DB.Exec("ALTER TABLE users ADD COLUMN nickname TEXT;")
	DB.Exec("ALTER TABLE users ADD COLUMN is_banned BOOLEAN DEFAULT 0;")

	if _, err := DB.Exec(queryChallenges); err != nil {
		return err
	}
	if _, err := DB.Exec(queryUserChallenges); err != nil {
		return err
	}

	// Seed some challenges if empty
	go seedChallenges()

	return nil
}

func seedChallenges() {
	challenges := []DailyChallenge{
		{"win_3", "Victory Streak", "Win 3 matches today", 3, 500, "wins"},
		{"play_5", "Card Shark", "Play 5 matches today", 5, 200, "games_played"},
		{"win_1000_coins", "Gold Digger", "Win 1000 coins in matches", 1000, 300, "coins_won"},
	}

	for _, c := range challenges {
		DB.Exec(`INSERT INTO challenges (id, title, description, goal, reward, type) 
				 VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET
				 goal=excluded.goal, reward=excluded.reward`,
			c.ID, c.Title, c.Description, c.Goal, c.Reward, c.Type)
	}
}

// GetOrCreateUser fetches a user or creates one if not exists
func GetOrCreateUser(userID string, name string) (*UserStats, error) {
	var user UserStats
	var dbName string

	var isBanned bool

	row := DB.QueryRow("SELECT user_id, name, nickname, avatar, games_played, wins, losses, coins, is_banned FROM users WHERE user_id = ?", userID)
	var dbNickname, dbAvatar sql.NullString
	err := row.Scan(&user.UserID, &dbName, &dbNickname, &dbAvatar, &user.GamesPlayed, &user.Wins, &user.Losses, &user.Coins, &isBanned)

	if isBanned {
		return nil, fmt.Errorf("USER_BANNED")
	}

	if err == sql.ErrNoRows {
		// Create new user (nickname defaults to name from fire auth)
		_, err := DB.Exec("INSERT INTO users (user_id, name, nickname, last_seen) VALUES (?, ?, ?, ?)", userID, name, name, time.Now())
		if err != nil {
			return nil, err
		}
		return &UserStats{UserID: userID, Name: name, GamesPlayed: 0, Wins: 0, Losses: 0, Rank: "Novice", Coins: 1000}, nil
	} else if err != nil {
		return nil, err
	}

	if dbNickname.Valid && dbNickname.String != "" {
		user.Name = dbNickname.String
	} else {
		user.Name = dbName
	}
	user.Rank = CalculateRank(user.Wins)

	// Update last seen
	DB.Exec("UPDATE users SET last_seen = ? WHERE user_id = ?", time.Now(), userID)

	return &user, nil
}

// UpdateUserCoins transactionally updates a user's coin balance.
// Returns error if insufficient funds for deduction.
func UpdateUserCoins(userID string, amount int) error {
	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Check balance if deducting
	if amount < 0 {
		var currentCoins int
		err := tx.QueryRow("SELECT coins FROM users WHERE user_id = ?", userID).Scan(&currentCoins)
		if err != nil {
			return err
		}
		if currentCoins+amount < 0 {
			return fmt.Errorf("insufficient funds")
		}
	}

	_, err = tx.Exec("UPDATE users SET coins = coins + ? WHERE user_id = ?", amount, userID)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// UpdateUserName updates the nickname for a user
func UpdateUserName(userID, newName string) error {
	_, err := DB.Exec("UPDATE users SET nickname = ? WHERE user_id = ?", newName, userID)
	return err
}

// UpdateUserAvatar updates the profile picture for a user
func UpdateUserAvatar(userID, newAvatar string) error {
	_, err := DB.Exec("UPDATE users SET avatar = ? WHERE user_id = ?", newAvatar, userID)
	return err
}

// RecordGameResult updates stats and saves match history
func RecordGameResult(matchID string, playerIDs []string, winnerID string, durationSec int, potAmount int) error {
	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Save Match
	playersJson, _ := json.Marshal(playerIDs)
	_, err = tx.Exec(`
		INSERT INTO matches (match_id, created_at, ended_at, players_json, winner_id) 
		VALUES (?, ?, ?, ?, ?)`,
		matchID, time.Now().Add(time.Duration(-durationSec)*time.Second), time.Now(), playersJson, winnerID,
	)
	if err != nil {
		return err
	}

	// 2. Update User Stats and Distribute Coins
	// Logic: Winner takes all. Pot = BootAmount * Players.
	// But BootAmount is deducted at start. So here we just ADD the total pot to winner.
	// NOTE: We don't track boot amount in matches table yet. Assuming passed in or default for now?
	// Actually, best to just pass 'potAmount' into this function.

	// winnerPot := 0 // Will need to update signature

	for _, pid := range playerIDs {
		isWinner := (pid == winnerID)

		winInc := 0
		lossInc := 0
		coinChange := 0

		if isWinner {
			winInc = 1
			coinChange = potAmount
		} else {
			lossInc = 1
		}

		// Use BufferCoinUpdate instead of direct DB write for coins
		if coinChange != 0 {
			BufferCoinUpdate(pid, coinChange)
		}

		// Update stats (wins/losses/games) directly, as these are less frequent than coin updates
		// and critical for immediate display. Coins can be eventually consistent.
		// Note: We REMOVED 'coins' from this update query to avoid over-writing the buffer logic.
		_, err = tx.Exec(`
			INSERT INTO users (user_id, name, games_played, wins, losses, last_seen)
			VALUES (?, ?, 1, ?, ?, ?)
			ON CONFLICT(user_id) DO UPDATE SET
				games_played = games_played + 1,
				wins = wins + excluded.wins,
				losses = losses + excluded.losses,
				last_seen = excluded.last_seen
		`,
			pid, "Unknown", winInc, lossInc, time.Now(),
		)
		if err != nil {
			return err
		}

		// Update Daily Challenge Progress
		UpdateChallengeProgress(pid, "games_played", 1)
		if isWinner {
			UpdateChallengeProgress(pid, "wins", 1)
			UpdateChallengeProgress(pid, "coins_won", potAmount)
		}
	}

	return tx.Commit()
}

// GetLeaderboard fetches top 50 players by wins
func GetLeaderboard() ([]UserStats, error) {
	query := `
		SELECT user_id, name, games_played, wins, losses 
		FROM users 
		ORDER BY wins DESC 
		LIMIT 50`

	rows, err := DB.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var leaderboard []UserStats
	for rows.Next() {
		var u UserStats
		if err := rows.Scan(&u.UserID, &u.Name, &u.GamesPlayed, &u.Wins, &u.Losses); err != nil {
			return nil, err
		}
		u.Rank = CalculateRank(u.Wins)
		leaderboard = append(leaderboard, u)
	}

	return leaderboard, nil
}

// -- Social / Friends --

type FriendRecord struct {
	UserID   string    `json:"userId"`
	FriendID string    `json:"friendId"`
	Status   string    `json:"status"`
	Name     string    `json:"name"`
	Rank     string    `json:"rank"`
	LastSeen time.Time `json:"lastSeen"`
	IsOnline bool      `json:"isOnline"`
}

// AddFriend creates a pending friend request
func AddFriend(userID, friendID string) error {
	_, err := DB.Exec(`
		INSERT INTO friends (user_id, friend_id, status, created_at)
		VALUES (?, ?, 'pending', ?)
		ON CONFLICT DO NOTHING`,
		userID, friendID, time.Now())
	return err
}

// AcceptFriend accepts a pending friend request (bidirectional)
func AcceptFriend(userID, friendID string) error {
	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Update the request
	_, err = tx.Exec("UPDATE friends SET status = 'accepted' WHERE user_id = ? AND friend_id = ?", friendID, userID)
	if err != nil {
		return err
	}

	// Create the reciprocal link
	_, err = tx.Exec(`
		INSERT INTO friends (user_id, friend_id, status, created_at)
		VALUES (?, ?, 'accepted', ?)
		ON CONFLICT(user_id, friend_id) DO UPDATE SET status = 'accepted'`,
		userID, friendID, time.Now())
	if err != nil {
		return err
	}

	return tx.Commit()
}

// GetFriends returns the list of friends for a user
func GetFriends(userID string) ([]FriendRecord, error) {
	query := `
		SELECT f.friend_id, f.status, u.name, u.wins, u.last_seen
		FROM friends f
		JOIN users u ON f.friend_id = u.user_id
		WHERE f.user_id = ?`

	rows, err := DB.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var friends []FriendRecord
	for rows.Next() {
		var f FriendRecord
		var wins int
		var ls time.Time
		if err := rows.Scan(&f.FriendID, &f.Status, &f.Name, &wins, &ls); err != nil {
			return nil, err
		}
		f.UserID = userID
		f.Rank = CalculateRank(wins)
		f.LastSeen = ls
		// Online if last seen in last 5 minutes
		f.IsOnline = time.Since(ls) < 5*time.Minute
		friends = append(friends, f)
	}

	return friends, nil
}

// -- Daily Challenges --

// GetDailyChallengesStatus returns all challenges with user progress
func GetDailyChallengesStatus(userID string) ([]map[string]interface{}, error) {
	query := `
		SELECT c.id, c.title, c.description, c.goal, c.reward, c.type, 
		       COALESCE(uc.current, 0) as current, 
		       COALESCE(uc.is_claimed, 0) as is_claimed
		FROM challenges c
		LEFT JOIN user_challenges uc ON c.id = uc.challenge_id AND uc.user_id = ?
	`
	rows, err := DB.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, title, desc, cType string
		var goal, reward, current int
		var isClaimed bool
		if err := rows.Scan(&id, &title, &desc, &goal, &reward, &cType, &current, &isClaimed); err != nil {
			return nil, err
		}

		results = append(results, map[string]interface{}{
			"id":          id,
			"title":       title,
			"description": desc,
			"goal":        goal,
			"reward":      reward,
			"type":        cType,
			"current":     current,
			"completed":   current >= goal,
			"isClaimed":   isClaimed,
		})
	}
	return results, nil
}

// UpdateChallengeProgress increments progress for a specific challenge type
func UpdateChallengeProgress(userID string, challengeType string, delta int) error {
	// 1. Find challenges of this type
	rows, err := DB.Query("SELECT id FROM challenges WHERE type = ?", challengeType)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var challengeID string
		rows.Scan(&challengeID)

		// 2. Update or insert progress
		_, err = DB.Exec(`
			INSERT INTO user_challenges (user_id, challenge_id, current, updated_at)
			VALUES (?, ?, ?, ?)
			ON CONFLICT(user_id, challenge_id) DO UPDATE SET
				current = current + excluded.current,
				updated_at = excluded.updated_at
		`, userID, challengeID, delta, time.Now())
		if err != nil {
			log.Printf("Error updating challenge %s for user %s: %v", challengeID, userID, err)
		}
	}
	return nil
}

// ClaimChallengeReward rewards the user and marks as claimed
func ClaimChallengeReward(userID string, challengeID string) (int, error) {
	tx, err := DB.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	// 1. Get challenge reward and check completion
	var reward, goal, current int
	var isClaimed bool
	err = tx.QueryRow(`
		SELECT c.reward, c.goal, COALESCE(uc.current, 0), COALESCE(uc.is_claimed, 0)
		FROM challenges c
		LEFT JOIN user_challenges uc ON c.id = uc.challenge_id AND uc.user_id = ?
		WHERE c.id = ?
	`, userID, challengeID).Scan(&reward, &goal, &current, &isClaimed)

	if err != nil {
		return 0, err
	}

	if current < goal {
		return 0, fmt.Errorf("challenge not completed")
	}
	if isClaimed {
		return 0, fmt.Errorf("reward already claimed")
	}

	// 2. Add coins to user (using buffer or direct)
	// For rewards, direct update is safer for immediate feedback if user is in UI
	_, err = tx.Exec("UPDATE users SET coins = coins + ? WHERE user_id = ?", reward, userID)
	if err != nil {
		return 0, err
	}

	// 3. Mark as claimed
	_, err = tx.Exec("UPDATE user_challenges SET is_claimed = 1 WHERE user_id = ? AND challenge_id = ?", userID, challengeID)
	if err != nil {
		return 0, err
	}

	return reward, tx.Commit()
}

// ResetDailyChallenges clears user progress (Call this via cron or daily trigger)
func ResetDailyChallenges() error {
	_, err := DB.Exec("DELETE FROM user_challenges")
	return err
}

func CalculateRank(wins int) string {
	switch {
	case wins < 5:
		return "Novice"
	case wins < 20:
		return "Apprentice"
	case wins < 50:
		return "Adept"
	case wins < 100:
		return "Expert"
	case wins < 200:
		return "Master"
	default:
		return "Legend"
	}
}

// DeleteUser removes all user data from the database
func DeleteUser(userID string) error {
	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Delete from users table
	_, err = tx.Exec("DELETE FROM users WHERE user_id = ?", userID)
	if err != nil {
		return err
	}

	// 2. Delete from friends table (both ways)
	_, err = tx.Exec("DELETE FROM friends WHERE user_id = ? OR friend_id = ?", userID, userID)
	if err != nil {
		return err
	}

	// Note: We keep match history (matches table) but the player info in players_json
	// will just refer to a non-existent user ID, which is fine for history preservation.

	return tx.Commit()
}

// BanUser marks a user as banned
func BanUser(userID string) error {
	_, err := DB.Exec("UPDATE users SET is_banned = 1 WHERE user_id = ?", userID)
	return err
}

// IsUserBanned checks if a user is banned
func IsUserBanned(userID string) (bool, error) {
	var isBanned bool
	err := DB.QueryRow("SELECT is_banned FROM users WHERE user_id = ?", userID).Scan(&isBanned)
	if err != nil {
		return false, err
	}
	return isBanned, nil
}
