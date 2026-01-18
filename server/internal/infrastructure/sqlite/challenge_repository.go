package sqlite

import (
	"database/sql"
	"fmt"
	"log"
	"time"
	"veil_server/internal/domain/challenge"
)

// ChallengeRepository implements challenge.Repository
type ChallengeRepository struct {
	db *sql.DB
}

func NewChallengeRepository(db *sql.DB) *ChallengeRepository {
	return &ChallengeRepository{db: db}
}

func (r *ChallengeRepository) GetDailyChallenges(userID string) ([]challenge.ChallengeWithProgress, error) {
	query := `
		SELECT c.id, c.title, c.description, c.goal, c.reward, c.type, 
		       COALESCE(uc.current, 0) as current, 
		       COALESCE(uc.is_claimed, 0) as is_claimed
		FROM challenges c
		LEFT JOIN user_challenges uc ON c.id = uc.challenge_id AND uc.user_id = ?
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []challenge.ChallengeWithProgress
	for rows.Next() {
		var c challenge.ChallengeWithProgress
		if err := rows.Scan(&c.ID, &c.Title, &c.Description, &c.Goal, &c.Reward, &c.Type, &c.Current, &c.IsClaimed); err != nil {
			return nil, err
		}
		c.Completed = c.Current >= c.Goal
		results = append(results, c)
	}
	return results, nil
}

func (r *ChallengeRepository) UpdateProgress(userID, challengeType string, delta int) error {
	// 1. Find challenges of this type
	rows, err := r.db.Query("SELECT id FROM challenges WHERE type = ?", challengeType)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var challengeID string
		rows.Scan(&challengeID)

		// 2. Update or insert progress
		_, err = r.db.Exec(`
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

func (r *ChallengeRepository) ClaimReward(userID, challengeID string) (int, error) {
	tx, err := r.db.Begin()
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

	// 2. Add coins to user
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

func (r *ChallengeRepository) ResetDailyProgress() error {
	_, err := r.db.Exec("DELETE FROM user_challenges")
	return err
}
