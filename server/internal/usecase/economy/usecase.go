package economy

import (
	"veil_server/internal/domain/economy"
)

type UseCase struct {
	repo economy.Repository
}

func NewUseCase(repo economy.Repository) *UseCase {
	return &UseCase{
		repo: repo,
	}
}

func (uc *UseCase) BufferCoinUpdate(userID string, amount int) {
	uc.repo.BufferCoinUpdate(userID, amount)
}

func (uc *UseCase) FlushCoins() error {
	return uc.repo.FlushCoins()
}

func (uc *UseCase) UpdateCoinsDirectly(userID string, amount int) error {
	return uc.repo.UpdateCoinsDirectly(userID, amount)
}
