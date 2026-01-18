package game

import (
	"veil_server/internal/domain/challenge"
	"veil_server/internal/domain/economy"
	"veil_server/internal/domain/match"
)

type UseCase struct {
	matchRepo     match.Repository
	challengeRepo challenge.Repository
	economyRepo   economy.Repository
}

func NewUseCase(m match.Repository, c challenge.Repository, e economy.Repository) *UseCase {
	return &UseCase{
		matchRepo:     m,
		challengeRepo: c,
		economyRepo:   e,
	}
}

func (uc *UseCase) RecordMatchResult(result match.MatchResult) error {
	// 1. Save Match Record and Update User Stats (Atomic in Repo)
	if err := uc.matchRepo.SaveResult(result); err != nil {
		return err
	}

	// 2. Post-Match Logic: Coins and Challenges
	// This logic was previously inside the DB transaction loop but can be independent
	for _, pid := range result.PlayerIDs {
		isWinner := (pid == result.WinnerID)

		// Coins (Winner takes Pot)
		if isWinner && result.PotAmount > 0 {
			uc.economyRepo.BufferCoinUpdate(pid, result.PotAmount)
		}

		// Challenges
		uc.challengeRepo.UpdateProgress(pid, "games_played", 1)
		if isWinner {
			uc.challengeRepo.UpdateProgress(pid, "wins", 1)
			if result.PotAmount > 0 {
				uc.challengeRepo.UpdateProgress(pid, "coins_won", result.PotAmount)
			}
		}
	}

	return nil
}

// GetDailyChallenges retrieves the daily challenges for a user
func (uc *UseCase) GetDailyChallenges(userID string) ([]challenge.ChallengeWithProgress, error) {
	return uc.challengeRepo.GetDailyChallenges(userID)
}

// ClaimDailyChallengeReward attempts to claim a reward for a completed challenge
func (uc *UseCase) ClaimDailyChallengeReward(userID, challengeID string) error {
	reward, err := uc.challengeRepo.ClaimReward(userID, challengeID)
	if err != nil {
		return err
	}

	// Buffer the coin reward
	uc.economyRepo.BufferCoinUpdate(userID, reward)
	return nil
}
