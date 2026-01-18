package social

import (
	"veil_server/internal/domain/social"
)

type UseCase struct {
	repo social.Repository
}

func NewUseCase(repo social.Repository) *UseCase {
	return &UseCase{
		repo: repo,
	}
}

func (uc *UseCase) AddFriendRequest(userID, friendID string) error {
	return uc.repo.AddFriendRequest(userID, friendID)
}

func (uc *UseCase) AcceptFriendRequest(userID, friendID string) error {
	return uc.repo.AcceptFriendRequest(userID, friendID)
}

func (uc *UseCase) GetFriends(userID string) ([]social.Friend, error) {
	return uc.repo.GetFriends(userID)
}

func (uc *UseCase) RemoveFriend(userID, friendID string) error {
	return uc.repo.RemoveFriend(userID, friendID)
}
