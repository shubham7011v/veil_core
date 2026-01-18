---
description: Refactor Server Room Architecture (Phase 6)
---
# Plan: Refactor `server/room` into `GameSession` (Domain) and `RoomActor` (Infrastructure)

## Objective
Decouple the game session logic (state management, rules enforcement, time management) from the underlying connection handling (websockets, broadcasting) and actor model (mutexes, channels).
This aligns with Clean Architecture:
- `GameSession` -> Domain Entity/Aggregate (Pure Go, no concurrency/IO)
- `RoomActor` (current `Room`) -> Infrastructure/Application Service (Handles IO, Mutexes, Networking)

## Step 1: Create `internal/domain/session` Package
Create `server/internal/domain/session` with:
- `entity.go`: Define `Session` struct.
  - Wraps `game.Game`.
  - Holds `id`, `configuration`, `timestamps`.
  - Methods for `Join`, `Leave`, `ProcessAction(userId, actionType, payload)`.
  - **Crucially**: Logic from `room.processAction` (parsing, validating, calling `game` methods) moves here.
  - Returns events/outcome, but does NOT broadcast.

## Step 2: Extract Logic from `room.go` to `session.go`
The `Room` in `server/room/room.go` is currently a God Object.
We will effectively keep `Room` as the "Actor" but delegate state updates to the new `Session`.

### Logic to Move to `UseCases` or `Domain`:
- `Room.processAction` (huge switch statement) should be handled by a UseCase or the domain entity.
  - `PlayCards`, `Pass`, `Challenge` -> `game.Game` methods (already done, but `room` orchestration needs cleanup).
  - `Voice`, `Chat` -> Can stay in `Room` (infrastructure) or move to a separate handler.
  - `AntiCheat` -> `Session` domain method.

## Step 3: Rename `Room`?
For now, we will keep the name `Room` in `server/room` to avoid breaking `Manager` integration too much, but essentially `Room` becomes the "Controller/Presenter" layer.

## Revised Plan for this session:
1.  **Define `GameSession` interface** in `internal/domain/session`.
2.  **Move "Game Orchestration" logic** from `room.go` into `Session` methods.
    - Examples: `IsFull`, `Join`, `Leave` (logic parts), `HandleTurnTimeout`.
3.  **Refactor `Room` to hold a definition of `Session`**.

**NOTE**: `game.Game` is *already* the domain entity. Adding another "Session" entity might be redundant wrapping.
**Better Approach**:
The `Room` code mixes *Network IO* (Broadcasting, WebRTC) with *Game Orchestration* (Timer checks, Auto-Pass, Bot Processing).
We should extract the *Orchestration* into a `GameOrchestrator` or `SessionManager`.

Let's stick to the simplest clean-up:
1.  **Extract `Room` methods** that are pure logic into `game` or a new `session` domain?
    - `IsPlayerInRoom` -> Logic.
    - `handleTurnTimeout` -> Logic (deciding what to do) + IO (broadcasting).

Actually, the previous instruction "Refactor Room: Split Room into GameSession (Domain) + RoomActor (Infrastructure)" implies a specific pattern.

**Proposed Split:**
- **Domain (`internal/domain/session`)**:
  - `Session`: Struct holding `game.Game`, `VoiceState`, `WebRTCManager`.
  - Methods: `AddPlayer`, `RemovePlayer`, `HandleMessage(msg) -> (Events, Error)`.
  - This struct is *synchronous* and *mutex-free*.
- **Infrastructure (`room/room.go`)**:
  - `Room`: Wraps `Session`.
  - Handles `Run()` loop, `Ticker`, `Channels`, `Mutex`.
  - Calls `Session.HandleMessage`, then iterates returned `Events` to `Broadcast`.

## Execution Steps
1.  Create `server/internal/domain/session/session.go`.
2.  Move fields `game`, `voice`, `webRTC`, `disconnectTimes` into `Session`.
3.  Implement `MsgType` handling in `Session` (returning events).
4.  Update `Room` to use `Session`.

**Wait**, this is a massive refactor that might break *everything* if done in one shot.
We will do it incrementally.

**Increment 1**: Extract `Voice` and `WebRTC` management out of `Room` main struct if possible, or leave as is.
**Increment 2**: Focus on `game` logic. `Room` currently calls `r.game.PlayCards`. This is already decent separation.

The main "smell" in `Room` is the huge `processAction` switch and the mixed dependencies.

Let's start by creating `internal/domain/session` and moving the *state* fields there.

```go
package session

import (
    "veil_server/game"
    "time"
)

type Validation interface {
    VerifyDeck() error
}

type Session struct {
   ID string
   Game *game.Game
   Settings RoomSettings
}
```

This might be over-engineering if `game.Game` is already the session.
The `Room` adds *persistence* (DB saving), *networking* (broadcasting), and *timing*.

Maybe the best step is just to clean up `processAction` into checking a `UseCase`.

**Decision**:
I will create `internal/domain/session/session.go` which aggregates `Game` and provides high-level methods that `Room` calls. This decouples `Room` (networking) from `Game` (logic rules).

// turbo
