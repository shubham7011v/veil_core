package stats

import (
	"veil_server/internal/domain/user"
)

type UseCase struct {
	repo user.Repository
}

func NewUseCase(repo user.Repository) *UseCase {
	return &UseCase{repo: repo}
}

func (uc *UseCase) GetLeaderboard() ([]user.User, error) {
	return uc.repo.GetLeaderboard(50)
}

func (uc *UseCase) GetMatchHistory(userID string) ([]user.MatchHistoryItem, error) {
	// UseCase defines the policy (limit 20)
	return uc.repo.GetMatchHistory(userID, 20)
}

// GetMatchHistory logic will need a new Repository method or interface?
// The current `user.Repository` doesn't have `GetMatchHistory` yet?
// Ah, `db.GetUserMatchHistory` exists.
// I should add `GetMatchHistory` to `user.Repository`.
