package auth

import (
	"context"
	"errors"
	"strings"
	"time"

	"veil_server/internal/domain/user"
)

// IdentityProvider handles 3rd party auth verification (Firebase)
type IdentityProvider interface {
	VerifyToken(ctx context.Context, token string) (uid, name, picture string, err error)
}

type UseCase struct {
	userRepo user.Repository
	idp      IdentityProvider
}

func NewUseCase(userRepo user.Repository, idp IdentityProvider) *UseCase {
	return &UseCase{
		userRepo: userRepo,
		idp:      idp,
	}
}

// Authenticate verifies the token and fetches/creates the user
func (uc *UseCase) Authenticate(ctx context.Context, token, providedName, providedAvatar string) (*user.User, error) {
	uid := token
	name := providedName
	avatar := providedAvatar

	// 1. Verify Token (if configured)
	if uc.idp != nil && !strings.HasPrefix(token, "mock_") {
		var err error
		var idpName, idpAvatar string
		// Use a bounded context for verification
		verifyCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()

		uid, idpName, idpAvatar, err = uc.idp.VerifyToken(verifyCtx, token)
		if err != nil {
			if err == context.DeadlineExceeded {
				return nil, errors.New("AUTH_TIMEOUT")
			}
			return nil, errors.New("AUTH_FAILED")
		}

		if providedName == "" && idpName != "" {
			name = idpName
		}
		if providedAvatar == "" && idpAvatar != "" {
			avatar = idpAvatar
		}
	}

	// 2. Fallback Name
	if name == "" {
		name = "Player"
	}

	u, err := uc.userRepo.GetOrCreate(uid, name)
	if err != nil {
		return nil, err
	}

	// 4. Update Avatar if provided from IDP
	if avatar != "" && avatar != u.AvatarURL {
		if err := uc.userRepo.UpdateProfile(uid, "", avatar); err == nil {
			u.AvatarURL = avatar
		}
	}

	return u, nil
}

func (uc *UseCase) UpdateName(uid, newName string) (*user.User, error) {
	if err := uc.userRepo.UpdateProfile(uid, newName, ""); err != nil {
		return nil, err
	}
	return uc.userRepo.GetOrCreate(uid, "") // Refetch to get stats
}

func (uc *UseCase) RefillCoins(uid string) (*user.User, error) {
	u, err := uc.userRepo.GetOrCreate(uid, "")
	if err != nil {
		return nil, err
	}

	if u.Coins >= 100 {
		return nil, errors.New("REFILL_DENIED") // You have enough
	}

	topUp := 1000 - u.Coins
	if err := uc.userRepo.UpdateCoins(uid, topUp); err != nil {
		return nil, err
	}

	u.Coins = 1000
	return u, nil
}

func (uc *UseCase) DeleteAccount(uid string) error {
	return uc.userRepo.DeleteUser(uid)
}

// GetUser retrieves a user by ID
func (uc *UseCase) GetUser(userID string) (*user.User, error) {
	return uc.userRepo.GetOrCreate(userID, "")
}
