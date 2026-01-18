package sqlite

import (
	"database/sql"
	"fmt"
	"log"
	"sync"
)

// EconomyRepository implements economy.Repository
type EconomyRepository struct {
	db      *sql.DB
	mu      sync.Mutex
	updates map[string]int // userID -> amountDelta
}

func NewEconomyRepository(db *sql.DB) *EconomyRepository {
	repo := &EconomyRepository{
		db:      db,
		updates: make(map[string]int),
	}
	return repo
}

func (r *EconomyRepository) BufferCoinUpdate(userID string, amount int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.updates[userID] += amount
}

func (r *EconomyRepository) FlushCoins() error {
	r.mu.Lock()
	updates := r.updates
	r.updates = make(map[string]int) // Reset buffer
	r.mu.Unlock()

	if len(updates) == 0 {
		return nil
	}

	// Helper to restore updates on failure
	restore := func() {
		r.mu.Lock()
		defer r.mu.Unlock()
		for uid, amount := range updates {
			r.updates[uid] += amount
		}
	}

	tx, err := r.db.Begin()
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
		}
	}

	if err := tx.Commit(); err != nil {
		restore()
		return fmt.Errorf("failed to commit transaction: %v", err)
	}

	log.Printf("Successfully flushed coin updates for %d users", len(updates))
	return nil
}

func (r *EconomyRepository) UpdateCoinsDirectly(userID string, amount int) error {
	tx, err := r.db.Begin()
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
