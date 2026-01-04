package db

import (
	"database/sql"
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

var DB *sql.DB

type UserStats struct {
	UserID      string `json:"userId"`
	Name        string `json:"name"`
	GamesPlayed int    `json:"gamesPlayed"`
	Wins        int    `json:"wins"`
	Losses      int    `json:"losses"`
	Rank        string `json:"rank"`
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

	if _, err := DB.Exec(queryUsers); err != nil {
		return err
	}
	if _, err := DB.Exec(queryMatches); err != nil {
		return err
	}

	return nil
}

// GetOrCreateUser fetches a user or creates one if not exists
func GetOrCreateUser(userID string, name string) (*UserStats, error) {
	var user UserStats
	var dbName string

	row := DB.QueryRow("SELECT user_id, name, games_played, wins, losses FROM users WHERE user_id = ?", userID)
	err := row.Scan(&user.UserID, &dbName, &user.GamesPlayed, &user.Wins, &user.Losses)

	if err == sql.ErrNoRows {
		// Create new user
		_, err := DB.Exec("INSERT INTO users (user_id, name, last_seen) VALUES (?, ?, ?)", userID, name, time.Now())
		if err != nil {
			return nil, err
		}
		return &UserStats{UserID: userID, Name: name, GamesPlayed: 0, Wins: 0, Losses: 0, Rank: "Novice"}, nil
	} else if err != nil {
		return nil, err
	}

	user.Name = dbName // return DB name in case it changed
	user.Rank = CalculateRank(user.Wins)

	// Update last seen
	DB.Exec("UPDATE users SET last_seen = ? WHERE user_id = ?", time.Now(), userID)

	return &user, nil
}

// RecordGameResult updates stats and saves match history
func RecordGameResult(matchID string, playerIDs []string, winnerID string, durationSec int) error {
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

	// 2. Update User Stats
	for _, pid := range playerIDs {
		isWinner := (pid == winnerID)

		winInc := 0
		lossInc := 0
		if isWinner {
			winInc = 1
		} else {
			lossInc = 1
		}

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
		return "Royale"
	}
}
