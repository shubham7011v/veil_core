package sqlite

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
	"veil_server/internal/domain/user"
)

// UserRepository implements user.Repository
type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) GetOrCreate(id, name string) (*user.User, error) {
	var u user.User
	var dbName string
	var isBanned bool
	var dbNickname, dbAvatar sql.NullString

	row := r.db.QueryRow("SELECT user_id, name, nickname, avatar, games_played, wins, losses, coins, is_banned FROM users WHERE user_id = ?", id)
	err := row.Scan(&u.ID, &dbName, &dbNickname, &dbAvatar, &u.GamesPlayed, &u.Wins, &u.Losses, &u.Coins, &isBanned)

	if isBanned {
		return nil, fmt.Errorf("USER_BANNED")
	}

	if err == sql.ErrNoRows {
		// Create new user
		_, err := r.db.Exec("INSERT INTO users (user_id, name, nickname, last_seen) VALUES (?, ?, ?, ?)", id, name, name, time.Now())
		if err != nil {
			return nil, err
		}
		newUser := &user.User{
			ID:          id,
			Name:        name,
			GamesPlayed: 0,
			Wins:        0,
			Losses:      0,
			Coins:       1000,
			LastSeen:    time.Now(),
		}
		newUser.CalculateRank()
		return newUser, nil
	} else if err != nil {
		return nil, err
	}

	if dbNickname.Valid && dbNickname.String != "" {
		u.Name = dbNickname.String
	} else {
		u.Name = dbName
	}

	if dbAvatar.Valid {
		u.AvatarURL = dbAvatar.String
	}

	u.CalculateRank()

	// Update last seen
	r.db.Exec("UPDATE users SET last_seen = ? WHERE user_id = ?", time.Now(), id)

	return &u, nil
}

func (r *UserRepository) UpdateCoins(id string, amount int) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if amount < 0 {
		var currentCoins int
		err := tx.QueryRow("SELECT coins FROM users WHERE user_id = ?", id).Scan(&currentCoins)
		if err != nil {
			return err
		}
		if currentCoins+amount < 0 {
			return fmt.Errorf("insufficient funds")
		}
	}

	_, err = tx.Exec("UPDATE users SET coins = coins + ? WHERE user_id = ?", amount, id)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *UserRepository) UpdateProfile(id, name, avatar string) error {
	if name != "" {
		_, err := r.db.Exec("UPDATE users SET nickname = ? WHERE user_id = ?", name, id)
		if err != nil {
			return err
		}
	}
	if avatar != "" {
		_, err := r.db.Exec("UPDATE users SET avatar = ? WHERE user_id = ?", avatar, id)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *UserRepository) GetLeaderboard(limit int) ([]user.User, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT user_id, name, nickname, games_played, wins, losses, coins 
		FROM users 
		ORDER BY wins DESC 
		LIMIT ?`

	rows, err := r.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var leaderboard []user.User
	for rows.Next() {
		var u user.User
		var dbName, dbNickname sql.NullString
		if err := rows.Scan(&u.ID, &dbName, &dbNickname, &u.GamesPlayed, &u.Wins, &u.Losses, &u.Coins); err != nil {
			return nil, err
		}
		if dbNickname.Valid && dbNickname.String != "" {
			u.Name = dbNickname.String
		} else if dbName.Valid {
			u.Name = dbName.String
		}
		u.CalculateRank()
		leaderboard = append(leaderboard, u)
	}

	return leaderboard, nil
}

func (r *UserRepository) BanUser(id string) error {
	_, err := r.db.Exec("UPDATE users SET is_banned = 1 WHERE user_id = ?", id)
	return err
}

func (r *UserRepository) DeleteUser(id string) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec("DELETE FROM users WHERE user_id = ?", id)
	if err != nil {
		return err
	}

	_, err = tx.Exec("DELETE FROM friends WHERE user_id = ? OR friend_id = ?", id, id)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *UserRepository) GetMatchHistory(userID string, limit int) ([]user.MatchHistoryItem, error) {
	if limit <= 0 {
		limit = 20
	}
	query := `
		SELECT match_id, created_at, ended_at, players_json, winner_id
		FROM matches
		WHERE players_json LIKE ?
		ORDER BY ended_at DESC
		LIMIT ?`

	rows, err := r.db.Query(query, "%"+userID+"%", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var history []user.MatchHistoryItem
	for rows.Next() {
		var m user.MatchHistoryItem
		var playersJSON string
		if err := rows.Scan(&m.MatchID, &m.CreatedAt, &m.EndedAt, &playersJSON, &m.WinnerID); err != nil {
			return nil, err
		}
		_ = json.Unmarshal([]byte(playersJSON), &m.PlayerIDs)
		history = append(history, m)
	}

	return history, nil
}
