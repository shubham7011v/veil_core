---
description: Plan for migrating legacy db calls to Clean Architecture Repositories
---

# Phase 5: Clean Architecture Migration Plan

## Objective
Eliminate direct dependencies on the legacy `db` package from the `room` package. Move all data access logic (Friends, Challenges, Game Results, Coin Buffering) into the `internal` layer repositories and use cases.

## Current State Analysis
The `room` package currently calls global functions in `db` for:
- **Social**: `AddFriend`, `AcceptFriend`, `GetFriends`
- **Challenges**: `GetDailyChallengesStatus`, `ClaimChallengeReward`
- **Game Results**: `RecordGameResult`
- **Economy**: `BufferCoinUpdate`
- **User Stats**: `GetOrCreateUser` (used in Broadcaster)

## Step 1: Define New Repository Interfaces
Create or update interfaces in `internal/domain` to cover the missing functionality.

### 1.1 Social Repository (`internal/domain/social`)
- Create `social` package.
- Define `Repository` interface:
  - `AddFriendRequest(userID, friendID string) error`
  - `AcceptFriendRequest(userID, friendID string) error`
  - `GetFriends(userID string) ([]Friend, error)`

### 1.2 Challenge Repository (`internal/domain/challenge`)
- Create `challenge` package.
- Define `Repository` interface:
  - `GetDailyChallenges(userID string) ([]ChallengeProgress, error)`
  - `ClaimReward(userID, challengeID string) (int, error)`
  - `UpdateProgress(userID, type string, delta int) error`

### 1.3 Economy Repository (`internal/domain/economy`)
- Create `economy` package (or add to `user`).
- Define `Repository` interface:
  - `BufferCoinUpdate(userID string, amount int)` (or similar transactional method)
  - `FlushCoins()`

## Step 2: Implement Infrastructure
Implement these interfaces in `internal/infrastructure/sqlite`.

- **Social**: Port `db.AddFriend`, `db.AcceptFriend`, `db.GetFriends` logic to `sqlite/social_repository.go`.
- **Challenges**: Port `db.GetDailyChallengesStatus`, `db.ClaimChallengeReward` to `sqlite/challenge_repository.go`.
- **Game Results**: Move `db.RecordGameResult` logic to a new implementation, possibly orchestrating updates across User, Match, and Challenge tables.

## Step 3: Create Use Cases
Use cases will wrap these repositories to provide clean APIs to the `Manager` and `Room`.

- **SocialUseCase**: `AddFriend`, `AcceptFriend`, `GetFriends`.
- **GameUseCase**: `RecordMatchResult` (handles history, stats update, coin distribution, challenge progress).
- **EconomyUseCase**: `ProcessTransaction`.

## Step 4: Refactor `Manager` and `Room`
Inject these new UseCases into `Manager` and `Room`.

1.  **Update `Manager` struct**: Add `SocialUC`, `GameUC`, `ChallengeUC`.
2.  **Update `NewManager`**: Initialize and inject the new UseCases.
3.  **Refactor `room.go`**: Replace `db.RecordGameResult` and `db.BufferCoinUpdate` with calls to `manager.GameUC` or `manager.EconomyUC`.
4.  **Refactor `auth_handler.go`**: Replace `db.GetFriends` and challenge calls with UseCase calls.

## Step 5: Deprecate `db` Package
Once `room` is fully migrated, the legacy `db` package global functions can be removed or marked deprecated, leaving only the `InitDB` and low-level SQL connection logic (or moving that to `infrastructure/sqlite` entirely).

## Execution Order
1.  **Social**: Migrate Friends features (Simple, low risk).
2.  **Challenges**: Migrate Daily Challenges (Moderate).
3.  **Economy/Game**: Migrate Coin buffering and Game Result recording (Critical path).
