# Online Multiplayer – Go WebSocket + Firebase Auth

## Architecture (LOCKED 🔒)

```mermaid
flowchart LR
    subgraph Flutter["Flutter Client"]
        UI[Session UI]
        SB[SessionBloc]
        WSH[WebSocketSessionHandler]
        FA[Firebase Auth]
    end
    
    subgraph Server["Go Server (Vultr Mumbai)"]
        WS[WebSocket Handler]
        RM[Room Manager]
        GE[Game Engine]
        TV[Token Verifier]
    end
    
    FA -->|ID Token| WSH
    WSH <-->|WebSocket| WS
    WS --> TV -->|Verify| FA
    WS --># Veil: Full App Production Roadmap

A comprehensive plan to build, test, and launch the complete Veil (Bluff) experience, including Social, Progression, and Scalable Multiplayer.

---

## The "Full App" Vision
The goal is to move beyond a simple card game engine into a complete social ecosystem. The "Full App" being tested locally will include:
- **Social**: Friends list, online status, private invites.
- **Progression**: Levels, XP, Ranks, and detailed Player Statistics.
- **Ecosphere**: Global leaderboards and a cosmetics shop.
- **Multiplayer**: Robust, server-authoritative WebSocket engine.

---

## **PHASE 1 IMPLEMENTATION (COMPLETED ✅)**

The Go Server scaffolding is complete and resides in `veil_core/server/`.

### Directory Structure

```
server/
├── main.go             # Entry point (Port 8080)
├── protocol/           # JSON Message Contracts
│   └── messages.go
├── room/               # Room & Client Management
│   ├── client.go       # WebSocket Read/Write Pumps
│   ├── manager.go      # Global Room Registry
│   └── room.go         # Game Loop & State Hub
├── game/               # Core Gameplay Logic (Engine)
│   ├── constants.go    # Phases, Max Players
│   ├── deck.go         # Card/Suit/Rank logic
│   ├── logic.go        # PlayCards/Pass/Challenge implementation
│   ├── player.go       # Hand management
│   └── state.go        # SessionState struct
└── main_test.go        # Integration Test (Auth -> Join -> Start)
```

### Verified Features
1.  **WebSocket Connectivity**: `gorilla/websocket` integration working.
2.  **Room System**: Dynamic creation of rooms (auto-creates "demo" room for now).
3.  **Game Engine**: Complete port of Bluff rules (Turn cycles, Challenges, Last Move tracking).
4.  **Integration**: `main_test.go` confirms 2 mock clients can join and start a game.

---

## **PHASE 2 PLAN (NEXT STEP)**

### Flutter Client
- Dependency: `web_socket_channel`
- Handler: `WebSocketSessionHandler.dart` implementing `GameSessionHandler` interface.
- UI: "Play Online" button in Lobby.

---

## Message Protocol (JSON over WebSocket)

### Client → Server

```json
// Auth (first message after connect)
{ "type": "AUTH", "token": "<firebase_id_token>" }

// Game Actions
{ "type": "PLAY_CARDS", "cardIds": ["c1", "c2"], "declaredRank": "seven" }
{ "type": "PASS" }
{ "type": "CHALLENGE" }
```

### Server → Client

```json
// Auth Response
{ "type": "AUTH_OK", "playerId": "uid123" }
{ "type": "AUTH_FAIL", "reason": "invalid_token" }

// Game State
{ "type": "GAME_STATE", "state": { /* full state */ } }
{ "type": "PLAYER_JOINED", "player": { "id": "...", "name": "..." } }
// Error
{ "type": "ERROR", "code": "NOT_YOUR_TURN", "message": "..." }
```

---

## Reference Commands
**Test Server (Local):** `go test -v ./server/...` or `cd server && go test -v`
**Run Server:** `cd server && go run .`
