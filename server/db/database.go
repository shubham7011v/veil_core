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

// FlushCoins writes all buffered coin updates to the DB in a single transaction
func FlushCoins() error {
	coinBuffer.mu.Lock()
	updates := coinBuffer.updates
	coinBuffer.updates = make(map[string]int) // Reset buffer
	coinBuffer.mu.Unlock()

	if len(updates) == 0 {
		return nil
	}

	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare("UPDATE users SET coins = coins + ? WHERE user_id = ?")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for uid, amount := range updates {
		if amount == 0 {
			continue
		}
		if _, err := stmt.Exec(amount, uid); err != nil {
			log.Printf("Failed to flush coins for user %s: %v", uid, err)
			// Continue to try other users, but this user's coins might be desynced until next login
		}
	}

	log.Printf("Flushed coin updates for %d users", len(updates))
	return tx.Commit()
}

type UserStats struct {
	UserID      string `json:"userId"`
	Name        string `json:"name"`
	GamesPlayed int    `json:"gamesPlayed"`
	Wins        int    `json:"wins"`
	Losses      int    `json:"losses"`
	Rank        string `json:"rank"`
	Coins       int    `json:"coins"`
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

	// Start background coin flusher
	StartCoinFlusher()

	return createTables()
}

func createTables() error {
	// Users Table
	queryUsers := `
	CREATE TABLE IF NOT EXISTS users (
		user_id TEXT PRIMARY KEY,
		name TEXT,
		avatar TEXT,
		games_played INTEGER DEFAULT 0,
		wins INTEGER DEFAULT 0,
		losses INTEGER DEFAULT 0,
		coins INTEGER DEFAULT 1000,
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

	return nil
}

// GetOrCreateUser fetches a user or creates one if not exists
func GetOrCreateUser(userID string, name string) (*UserStats, error) {
	var user UserStats
	var dbName string

	row := DB.QueryRow("SELECT user_id, name, games_played, wins, losses, coins FROM users WHERE user_id = ?", userID)
	err := row.Scan(&user.UserID, &dbName, &user.GamesPlayed, &user.Wins, &user.Losses, &user.Coins)

	if err == sql.ErrNoRows {
		// Create new user
		_, err := DB.Exec("INSERT INTO users (user_id, name, last_seen) VALUES (?, ?, ?)", userID, name, time.Now())
		if err != nil {
			return nil, err
		}
		return &UserStats{UserID: userID, Name: name, GamesPlayed: 0, Wins: 0, Losses: 0, Rank: "Novice", Coins: 1000}, nil
	} else if err != nil {
		return nil, err
	}

	user.Name = dbName // return DB name in case it changed
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

// UpdateUserName updates the display name for a user
func UpdateUserName(userID, newName string) error {
	_, err := DB.Exec("UPDATE users SET name = ? WHERE user_id = ?", newName, userID)
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
