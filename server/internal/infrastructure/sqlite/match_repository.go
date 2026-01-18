package sqlite

import (
	"database/sql"
	"encoding/json"
	"time"
	"veil_server/internal/domain/match"
)

type MatchRepository struct {
	db *sql.DB
}

func NewMatchRepository(db *sql.DB) *MatchRepository {
	return &MatchRepository{db: db}
}

func (r *MatchRepository) SaveResult(result match.MatchResult) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Save Match
	playersJson, _ := json.Marshal(result.PlayerIDs)
	metadataJson, _ := json.Marshal(result.Metadata)

	// Note: created_at calculation to match legacy logic (EndedAt - Duration)
	startedAt := result.EndedAt.Add(time.Duration(-result.DurationSec) * time.Second)

	_, err = tx.Exec(`
		INSERT INTO matches (match_id, created_at, ended_at, players_json, winner_id, metadata) 
		VALUES (?, ?, ?, ?, ?, ?)`,
		result.MatchID, startedAt, result.EndedAt, playersJson, result.WinnerID, metadataJson,
	)
	if err != nil {
		return err
	}

	// 2. Update User Stats (Wins/Losses)
	for _, pid := range result.PlayerIDs {
		isWinner := (pid == result.WinnerID)

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
