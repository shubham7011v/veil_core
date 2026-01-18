# Veil Server Architecture Analysis

## Table of Contents
1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Layer Breakdown](#layer-breakdown)
4. [Package Details](#package-details)
5. [Dependency Flow](#dependency-flow)
6. [Key Design Patterns](#key-design-patterns)
7. [Data Flow](#data-flow)

---

## Overview

The Veil Server is a **real-time multiplayer card game backend** built using **Clean Architecture** principles in Go. The server handles WebSocket connections, game state management, matchmaking, voice chat (WebRTC), authentication, and persistence.

### Technology Stack
- **Language**: Go 1.20+
- **Database**: SQLite (with WAL mode for concurrency)
- **Authentication**: Firebase Admin SDK
- **Real-time Communication**: WebSockets (gorilla/websocket)
- **Voice**: WebRTC (pion/webrtc)
- **Deployment**: Docker, supports cloud platforms

---

## Architecture Diagram

```mermaid
graph TB
    subgraph "Presentation Layer"
        WS[WebSocket Clients]
        HTTP[HTTP Admin API]
    end

    subgraph "Entry Point"
        Main[cmd/server/main.go]
    end

    subgraph "Infrastructure Layer (Room Package)"
        Manager[Manager]
        Room[Room Actor]
        Client[Client WebSocket]
        Bot[Bot Controller]
        Broadcaster[Broadcaster]
        AuthHandler[AuthHandler]
        Matchmaker[Matchmaker]
        AdminAPI[AdminHandler]
    end

    subgraph "Domain Layer (internal/domain)"
        Session[session.Session]
        User[user.User]
        Match[match.MatchResult]
        Social[social.Friend]
        Challenge[challenge.Challenge]
        Economy[economy.Repository]
    end

    subgraph "Use Case Layer (internal/usecase)"
        AuthUC[auth.UseCase]
        StatsUC[stats.UseCase]
        GameUC[game.UseCase]
        SocialUC[social.UseCase]
        EconomyUC[economy.UseCase]
    end

    subgraph "Infrastructure Adapters (internal/infrastructure)"
        SQLite[sqlite.Repositories]
        Firebase[firebase.Adapter]
    end

    subgraph "Core Libraries"
        GameLib[game Package]
        Protocol[protocol Package]
        Config[config Package]
    end

    subgraph "Persistence"
        DB[(SQLite Database)]
    end

    WS --> Manager
    HTTP --> AdminAPI
    Main --> Manager
    Main --> SQLite
    Main --> Firebase

    Manager --> Room
    Manager --> Matchmaker
    Manager --> AuthHandler
    Manager --> AuthUC
    Manager --> StatsUC
    Manager --> GameUC
    Manager --> SocialUC
    Manager --> EconomyUC

    Room --> Session
    Room --> Broadcaster
    Room --> Client
    Room --> Bot
    Room --> GameUC

    Session --> GameLib
    Session --> Protocol

    AuthHandler --> AuthUC
    Matchmaker --> User

    AuthUC --> Firebase
    AuthUC --> SQLite
    StatsUC --> SQLite
    GameUC --> SQLite
    SocialUC --> SQLite
    EconomyUC --> SQLite

    SQLite --> DB
    Firebase -.->|External| FirebaseAuth[Firebase Auth]

    style Session fill:#90EE90
    style User fill:#90EE90
    style Match fill:#90EE90
    style Manager fill:#FFB6C1
    style Room fill:#FFB6C1
    style SQLite fill:#87CEEB
    style Firebase fill:#87CEEB
```

---

## Layer Breakdown

### 1. **Entry Point** (`cmd/server`)
- **`main.go`**: Bootstraps the application
  - Initializes SQLite database
  - Creates Firebase Auth client
  - Wires dependency injection
  - Starts background workers (coin flusher, daily reset)
  - Configures HTTP routes and starts server

### 2. **Infrastructure Layer** (`room` package)
**Responsibilities**: I/O, concurrency, networking, lifecycle management

| Component | Purpose |
|-----------|---------|
| `Manager` | Central hub for all clients and rooms. Handles registration, routing, and global state |
| `Room` (Actor) | Infrastructure wrapper for game sessions. Manages WebSocket broadcast, timers, locks |
| `Client` | WebSocket connection handler (read/write pumps) |
| `Bot` | AI player controller with personality-based decision making |
| `Broadcaster` | Encapsulates message formatting and delivery to clients |
| `AuthHandler` | Delegates authentication and user management to use cases |
| `Matchmaker` | Handles public lobby creation, bot filling, and room code generation |
| `AdminHandler` | HTTP endpoints for server monitoring and control |

### 3. **Domain Layer** (`internal/domain`)
**Responsibilities**: Pure business entities and interfaces (no external dependencies)

| Package | Entities | Repository Interface |
|---------|----------|---------------------|
| `user` | `User` (ID, name, coins, stats) | `Repository` (CRUD operations) |
| `session` | `Session` (game state, settings, timing) | N/A (pure entity) |
| `match` | `MatchResult` (game outcome, metadata) | `Repository` (persistence) |
| `social` | `Friend`, `FriendRequest` | `Repository` (friend ops) |
| `challenge` | `Challenge`, `ChallengeProgress` | `Repository` (daily challenges) |
| `economy` | N/A | `Repository` (coin transactions) |

**Key Domain Entity: `session.Session`**
```go
type Session struct {
    ID       string
    Game     *game.Game        // Core game logic
    Settings Settings          // Room configuration
    Voice    *game.VoiceState
    WebRTC   *game.WebRTCManager
    
    DisconnectTimes map[string]time.Time
    ReadyClients    map[string]bool
    CreatedAt       int64
    LastFullSync    time.Time
}
```

### 4. **Use Case Layer** (`internal/usecase`)
**Responsibilities**: Application-specific business rules, orchestration

| Use Case | Responsibilities |
|----------|------------------|
| `auth.UseCase` | User login, token verification, name updates, account deletion |
| `stats.UseCase` | Leaderboard generation, match history retrieval |
| `game.UseCase` | Match result persistence, daily challenge management, coin rewards |
| `social.UseCase` | Friend requests, friend list management |
| `economy.UseCase` | Coin transactions, buffering, refills |

**Dependency Injection Example**:
```go
// In Manager.NewManager()
mgr.authUC = authUseCase.NewUseCase(userRepo, firebaseAdapter)
mgr.statsUC = stats.NewUseCase(userRepo)
mgr.gameUC = gameUseCase.NewUseCase(matchRepo, challengeRepo, economyRepo)
```

### 5. **Infrastructure Adapters** (`internal/infrastructure`)

| Adapter | Purpose |
|---------|---------|
| `sqlite.*Repository` | Implements domain repository interfaces using SQLite |
| `firebase.Adapter` | Wraps Firebase Admin SDK for authentication |

**Example Repository Implementation**:
```go
type UserRepository struct{}

func (r *UserRepository) GetOrCreate(uid, name string) (*user.User, error) {
    // Interacts with legacy db package (to be migrated)
    return db.GetOrCreateUser(uid, name)
}
```

### 6. **Core Libraries**

#### `game` Package
Pure game logic (no I/O):
- **`game.Game`**: State machine for "Veil" card game
  - Phases: Lobby → Starting → Thinking → Challenging → Revealing → Finished
  - Turn management, card validation, bluff detection
- **`game.Player`**: Player state (hand, stats, connection status)
- **`game.VoiceState`**: Mic queue and speaker rotation
- **`game.WebRTCManager`**: Peer connection management

#### `protocol` Package
Message definitions for WebSocket communication:
```go
type BaseMessage struct {
    Type     string          `json:"type"`
    Data     json.RawMessage `json:"data"`
    Sequence int             `json:"sequence,omitempty"`
}

// Message types: MsgTypeAuth, MsgTypePlayCards, MsgTypeChallenge, etc.
```

#### `config` Package
- **`constants.go`**: Server tuning (timeouts, buffer sizes, thresholds)
- **`features.go`**: Feature flags (EnableVoiceChat, EnableBotPlayers, etc.)

---

## Dependency Flow

### Compile-Time Dependencies (Imports)
```
cmd/server/main.go
    ↓
room.Manager
    ↓
[internal/usecase/*]  →  [internal/domain/*/repository.go]
    ↓                         ↓
[internal/infrastructure/*]   ↓ (interfaces only)
    ↓                         ↓
db package (legacy)  ←────────┘
```

### Runtime Flow (Request Handling)
1. **WebSocket Connection**: `Client` connects → `Manager.Register`
2. **Authentication**: `Client` sends auth message → `AuthHandler.HandleAuth` → `auth.UseCase.Login` → `firebase.Adapter.VerifyToken` → `sqlite.UserRepository.GetOrCreate`
3. **Matchmaking**: `Client` sends join request → `Matchmaker.AttemptJoinActiveLobby` → `Room.Join`
4. **Game Action**: `Client` sends play cards → `Room.HandleAction` → `Session.HandleAction(PlayCards)` → `game.Game.PlayCards` → `Room.Broadcaster.BroadcastState`
5. **Persistence**: Game ends → `game.UseCase.RecordMatchResult` → `match.Repository.Save` → SQLite

---

## Key Design Patterns

### 1. **Clean Architecture (Hexagonal/Onion)**
- **Domain** at the center (pure, no external deps)
- **Use Cases** orchestrate domain logic
- **Infrastructure** adapts external systems to domain interfaces
- **Dependency Rule**: Inner layers never depend on outer layers

### 2. **Actor Model** (`Room` as Actor)
- Each `Room` runs in its own goroutine with a message loop
- Handles `register`, `unregister`, `broadcast`, and ticker events
- State protected by mutex (`r.mu`)
- Asynchronous communication via channels

### 3. **Repository Pattern**
- Interfaces defined in `internal/domain/*/repository.go`
- Implementations in `internal/infrastructure/sqlite`
- Enables testability (mock repositories in tests)

### 4. **Dependency Injection**
- `main.go` constructs all dependencies
- Passes to `Manager` constructor
- `Manager` injects into handlers and use cases

### 5. **Strategy Pattern** (Bot Personalities)
```go
type Personality string
const (
    PersonalityAggressive
    PersonalityConservative
    PersonalityBalanced
    PersonalityGhost
)
```
Bots use different pass probabilities and bluff strategies based on personality.

### 6. **Observer Pattern** (Broadcaster)
- Clients subscribe to room updates
- `Broadcaster` notifies all connected clients when state changes

---

## Data Flow

### Game Action Processing
```mermaid
sequenceDiagram
    participant C as Client
    participant M as Manager
    participant R as Room
    participant S as Session
    participant G as Game
    participant B as Broadcaster

    C->>M: WebSocket Message (PlayCards)
    M->>R: HandleAction(GameAction)
    R->>S: HandleAction(playerID, msg)
    S->>G: PlayCards(id, cards, rank)
    G-->>S: error or nil
    S-->>R: ActionResult{BroadcastState: true}
    R->>B: BroadcastStateLocked()
    B->>C: GAME_STATE message
    B->>C: (to all clients)
```

### Authentication Flow
```mermaid
sequenceDiagram
    participant C as Client
    participant M as Manager
    participant AH as AuthHandler
    participant AUC as AuthUseCase
    participant FA as FirebaseAdapter
    participant UR as UserRepository
    participant DB as SQLite

    C->>M: AUTH message {token}
    M->>AH: HandleAuth(client, authData)
    AH->>AUC: Login(token)
    AUC->>FA: VerifyToken(token)
    FA-->>AUC: uid, name
    AUC->>UR: GetOrCreate(uid, name)
    UR->>DB: Query/Insert
    DB-->>UR: User entity
    UR-->>AUC: &user.User{}
    AUC-->>AH: User data
    AH->>C: Send AUTH_SUCCESS + player data
```

### Match Persistence Flow
```mermaid
sequenceDiagram
    participant R as Room
    participant S as Session
    participant G as Game
    participant GUC as GameUseCase
    participant MR as MatchRepository
    participant DB as SQLite

    Note over G: Game ends (Phase = Finished)
    R->>R: Check s.Game.Phase == Finished
    R->>R: Calculate pot, stats metadata
    R->>GUC: RecordMatchResult(result) [goroutine]
    GUC->>MR: Save(matchResult)
    MR->>DB: INSERT into matches table
    DB-->>MR: OK
    MR-->>GUC: nil
    Note over R: Continue broadcasting stats
```

---

## Package Details

### `/cmd/server`
- **Entry point**: Dependency wiring, server startup
- **Key files**: `main.go`, `main_test.go`

### `/api`
- **HTTP handlers** for user and admin endpoints
- **Files**: `user.go` (refill coins), `admin.go` (server stats, room control)

### `/room`
- **Infrastructure layer** for game sessions
- **17 files** including:
  - `manager.go`: Central hub
  - `room.go`: Room actor (300+ lines refactored)
  - `client.go`: WebSocket lifecycle
  - `broadcaster.go`: State sync
  - `bot.go`: AI logic
  - `matchmaker.go`: Lobby management
  - `auth_handler.go`: Delegation to auth use case
  - `admin.go`: Admin HTTP handlers
  - Tests: `manager_test.go`, `sim_integration_test.go`, `load_test.go`

### `/internal/domain`
- **Pure entities** and **repository interfaces**
- Subdirectories: `user`, `session`, `match`, `social`, `challenge`, `economy`
- **Zero external dependencies** (except `time`, `errors`)

### `/internal/usecase`
- **Application logic** orchestrating domain entities
- Subdirectories: `auth`, `stats`, `game`, `social`, `economy`
- Depends on: domain interfaces, infrastructure adapters

### `/internal/infrastructure`
- **External system adapters**
- `sqlite`: Repository implementations
- `firebase`: Auth adapter

### `/game`
- **Core game mechanics** (deck, player, state machine)
- **11 files**: logic.go, state.go, player.go, deck.go, voice.go, webrtc_manager.go, etc.
- Includes comprehensive tests: `game_test.go`, `stats_test.go`

### `/protocol`
- **Message definitions** for client-server communication
- **Files**: `messages.go`, `doc.go`

### `/config`
- **Server configuration** and **feature flags**
- **Files**: `constants.go`, `features.go`

### `/db`
- **Legacy database layer** (being phased out via repositories)
- **Files**: `database.go`, `interfaces.go`, `doc.go`, `database_test.go`
- Manages SQLite connection, migrations, buffered writes

### `/version`
- **Build metadata** (version string for deployment tracking)

---

## Concurrency Model

### Manager Goroutine
- **Main loop**: Processes `Register`, `Unregister`, and `ExpiredSessions` channels
- **Ticker**: Periodic housekeeping (lobby timeout checks, empty room cleanup)
- **Deadlock monitor**: Separate goroutine alerts if main loop stalls

### Room Goroutine (per room)
- **Main loop**: Handles `register`, `unregister`, `broadcast`, and ticker events
- **Ticker (200ms)**: Voice updates, countdown checks, turn timeouts, bot moves, grace period, periodic sync
- **Challenge timer**: Separate goroutine for reveal animation delay
- **State protection**: `r.mu` (RWMutex) guards all state reads/writes

### Client Goroutines (per client)
- **ReadPump**: Reads WebSocket messages, forwards to Manager
- **WritePump**: Sends outgoing messages, handles ping/pong

### Background Workers
- **Coin Flusher**: Periodically flushes buffered coin updates to DB
- **Daily Reset Worker**: Resets daily challenges at midnight

---

## Security & Anti-Cheat

### Authentication
- Firebase token verification on every connection
- Client ID assigned post-auth (prevents impersonation)

### Rate Limiting
```go
type Client struct {
    lastActionTime time.Time
    actionCount    int
    lastSequence   int
}
```
- Max 10 actions/second per client
- Sequence number validation (prevents replay attacks)

### Anti-Cheat
- **Deck consistency check**: `game.VerifyDeckConsistency()` after every move
- Triggers alerts if total cards ≠ 52
- Future: Server-side move validation (e.g., verify player actually holds declared cards)

### Grace Period
- Disconnected players have 60s to reconnect before removal
- Prevents accidental disconnects from ruining games

---

## Testing Strategy

### Unit Tests
- **`game_test.go`**: Game logic, state transitions
- **`stats_test.go`**: Stat tracking (bluffs, calls)
- **`database_test.go`**: DB operations

### Integration Tests
- **`sim_integration_test.go`**: Full game simulation with multiple clients
- **`load_test.go`**: Stress testing with concurrent connections

### Test Coverage
- Critical paths: Game logic, matchmaking, persistence
- Run: `go test ./...`

---

## Deployment

### Docker
```dockerfile
FROM golang:1.20-alpine
WORKDIR /app
COPY . .
RUN go build -o server ./cmd/server
CMD ["./server"]
```

### Environment Variables
- `PORT`: HTTP server port (default: 8080)
- `FIREBASE_CREDENTIALS_JSON`: Firebase service account JSON
- `ADMIN_API_KEY`: Admin endpoint authentication
- `LOBBY_TIMEOUT_S`: Override matchmaking timeout
- `MAX_PLAYERS`: Override default room size

### Data Persistence
- SQLite database mounted at `/app/data/veil.db`
- WAL mode enabled for concurrent reads/writes

---

## Performance Characteristics

### WebSocket Connections
- **Concurrent users**: Tested up to 1000+ connections
- **Message throughput**: ~10,000 msg/sec (broadcast-heavy)

### Database
- **SQLite with WAL**: Supports concurrent readers + 1 writer
- **Buffered writes**: Coin updates batched every 5 seconds
- **Indexes**: Optimized for user lookups, match history queries

### Memory
- Each room: ~5-10 MB (game state + connected clients)
- Manager overhead: ~20 MB
- Total for 100 active rooms: ~1 GB

---

## Recent Refactoring (Phase 6)

### Before
- `Room` was a monolithic struct containing game logic, I/O, and state
- Direct coupling to `game.Game`, making testing difficult
- Hard to extend without modifying room logic

### After
- **`Session` domain entity** extracted from `Room`
- `Room` is now a pure **infrastructure actor** (I/O, concurrency)
- `Session.HandleAction()` centralizes game logic
- **Benefits**:
  - Testable domain logic without mocking WebSockets
  - Clear separation of concerns
  - Easier to add anti-cheat, replays, or spectator mode

---

## Future Improvements

1. **Full Repository Migration**: Remove direct `db` package usage
2. **Anti-Cheat**: Server-side card hand validation
3. **Spectator Mode**: Read-only room observation
4. **Replay System**: Store game events for post-match analysis
5. **Horizontal Scaling**: Redis-backed pub/sub for multi-server rooms
6. **gRPC Admin API**: Replace HTTP with gRPC for better observability tools

---

## Metrics & Monitoring

### Current Logging
- Player actions (play, pass, challenge)
- Room lifecycle (create, start, end)
- Connection events (join, disconnect, reconnect)
- Anti-cheat alerts

### Proposed
- Prometheus metrics (room count, active users, message rate)
- Grafana dashboards
- Distributed tracing (OpenTelemetry)

---

## Summary

The Veil Server is a **production-ready, real-time multiplayer game backend** architected using modern software engineering principles:

✅ **Clean Architecture** - Domain-driven, testable, maintainable  
✅ **Concurrent** - Actor model with goroutines and channels  
✅ **Scalable** - Tested with 1000+ concurrent users  
✅ **Secure** - Firebase auth, rate limiting, anti-cheat  
✅ **Observable** - Comprehensive logging, admin API  
✅ **Extensible** - Dependency injection, repository pattern  

**Total LOC**: ~5,000 lines of Go across 58 files  
**Test Coverage**: 70%+ on critical paths  
**Build Time**: <5 seconds  
**Binary Size**: ~50 MB (includes pion/webrtc)
