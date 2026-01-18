package sqlite

import (
	"database/sql"
	"time"
	"veil_server/internal/domain/social"
)

// SocialRepository implements social.Repository
type SocialRepository struct {
	db *sql.DB
}

func NewSocialRepository(db *sql.DB) *SocialRepository {
	return &SocialRepository{db: db}
}

func (r *SocialRepository) AddFriendRequest(userID, friendID string) error {
	_, err := r.db.Exec(`
		INSERT INTO friends (user_id, friend_id, status, created_at)
		VALUES (?, ?, 'pending', ?)
		ON CONFLICT DO NOTHING`,
		userID, friendID, time.Now())
	return err
}

func (r *SocialRepository) AcceptFriendRequest(userID, friendID string) error {
	tx, err := r.db.Begin()
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

func (r *SocialRepository) RemoveFriend(userID, friendID string) error {
	_, err := r.db.Exec("DELETE FROM friends WHERE (user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)", userID, friendID, friendID, userID)
	return err
}

func (r *SocialRepository) GetFriends(userID string) ([]social.Friend, error) {
	query := `
		SELECT f.friend_id, f.status, u.name, u.wins, u.last_seen
		FROM friends f
		JOIN users u ON f.friend_id = u.user_id
		WHERE f.user_id = ?`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var friends []social.Friend
	for rows.Next() {
		var f social.Friend
		var status string
		var wins int
		var ls time.Time
		if err := rows.Scan(&f.FriendID, &status, &f.Name, &wins, &ls); err != nil {
			return nil, err
		}
		f.UserID = userID
		f.Status = social.FriendStatus(status)
		f.Rank = CalculateRank(wins)
		f.LastSeen = ls
		f.IsOnline = time.Since(ls) < 5*time.Minute
		friends = append(friends, f)
	}

	return friends, nil
}

func (r *SocialRepository) GetPendingRequests(userID string) ([]social.Friend, error) {
	query := `
		SELECT f.friend_id, f.status, u.name, u.wins, u.last_seen
		FROM friends f
		JOIN users u ON f.friend_id = u.user_id
		WHERE f.user_id = ? AND f.status = 'pending'`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var friends []social.Friend
	for rows.Next() {
		var f social.Friend
		var status string
		var wins int
		var ls time.Time
		if err := rows.Scan(&f.FriendID, &status, &f.Name, &wins, &ls); err != nil {
			return nil, err
		}
		f.UserID = userID
		f.Status = social.FriendStatus(status)
		f.Rank = CalculateRank(wins)
		f.LastSeen = ls
		f.IsOnline = time.Since(ls) < 5*time.Minute
		friends = append(friends, f)
	}

	return friends, nil
}

// Helper (Moved from db/database.go logic)
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
