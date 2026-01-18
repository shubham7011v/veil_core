package db

import (
	"database/sql"
	"embed"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"veil_server/internal/domain/challenge"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/sqlite"
	"github.com/golang-migrate/migrate/v4/source/iofs"

	_ "modernc.org/sqlite"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// InitDB initializes the SQLite database and runs migrations
func InitDB(dbPath string) (*sql.DB, error) {
	// Ensure directory exists
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, err
	}

	var err error
	actualPath := dbPath
	if dbPath == ":memory:" {
		actualPath = "file::memory:?cache=shared"
	}
	dbConn, err := sql.Open("sqlite", actualPath)
	if err != nil {
		return nil, err
	}

	if err = dbConn.Ping(); err != nil {
		return nil, err
	}

	log.Println("Database connected at", dbPath)

	// Enable Write-Ahead Logging (WAL) for concurrency
	if _, err := dbConn.Exec("PRAGMA journal_mode=WAL;"); err != nil {
		return nil, fmt.Errorf("failed to enable WAL mode: %v", err)
	}
	// Set busy timeout to prevent "database is locked" errors
	if _, err := dbConn.Exec("PRAGMA busy_timeout=5000;"); err != nil {
		return nil, fmt.Errorf("failed to set busy timeout: %v", err)
	}

	// Run migrations
	if err := runMigrations(dbConn); err != nil {
		return nil, err
	}

	// Seed some challenges if empty
	go seedChallenges(dbConn)

	return dbConn, nil
}

func runMigrations(dbConn *sql.DB) error {
	driver, err := sqlite.WithInstance(dbConn, &sqlite.Config{})
	if err != nil {
		return fmt.Errorf("could not setup migration driver: %v", err)
	}

	source, err := iofs.New(migrationsFS, "migrations")
	if err != nil {
		return fmt.Errorf("could not setup migration source: %v", err)
	}

	m, err := migrate.NewWithInstance("iofs", source, "sqlite", driver)
	if err != nil {
		return fmt.Errorf("could not create migration instance: %v", err)
	}

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return fmt.Errorf("failed to apply migrations: %v", err)
	}

	log.Println("Migrations applied successfully")
	return nil
}

func seedChallenges(dbConn *sql.DB) {
	challenges := []challenge.Challenge{
		{
			ID:          "win_3",
			Title:       "Victory Streak",
			Description: "Win 3 matches today",
			Goal:        3,
			Reward:      500,
			Type:        "wins",
		},
		{
			ID:          "play_5",
			Title:       "Card Shark",
			Description: "Play 5 matches today",
			Goal:        5,
			Reward:      200,
			Type:        "games_played",
		},
		{
			ID:          "win_1000_coins",
			Title:       "Gold Digger",
			Description: "Win 1000 coins in matches",
			Goal:        1000,
			Reward:      300,
			Type:        "coins_won",
		},
	}

	for _, c := range challenges {
		dbConn.Exec(`INSERT INTO challenges (id, title, description, goal, reward, type) 
				 VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET
				 goal=excluded.goal, reward=excluded.reward`,
			c.ID, c.Title, c.Description, c.Goal, c.Reward, c.Type)
	}
}
