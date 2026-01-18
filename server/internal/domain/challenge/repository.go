package challenge

// Repository defines the interface for challenge operations
type Repository interface {
	// GetDailyChallenges retrieves all available challenges with the user's progress
	GetDailyChallenges(userID string) ([]ChallengeWithProgress, error)

	// UpdateProgress increments the progress for a specific challenge type
	// Note: This matches the 'UpdateChallengeProgress' in legacy db
	UpdateProgress(userID, challengeType string, delta int) error

	// ClaimReward verifies completion and marks the challenge as claimed
	// Returns the reward amount if successful
	ClaimReward(userID, challengeID string) (int, error)

	// ResetDailyProgress clears all user progress (for cron jobs)
	ResetDailyProgress() error
}
