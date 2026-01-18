package economy

// Repository defines the interface for economy-related operations
type Repository interface {
	// BufferCoinUpdate queues a coin update to be written later (high frequency)
	BufferCoinUpdate(userID string, amount int)

	// FlushCoins processes the buffered updates
	FlushCoins() error

	// UpdateCoinsDirectly performs an immediate, transactional update
	UpdateCoinsDirectly(userID string, amount int) error
}
