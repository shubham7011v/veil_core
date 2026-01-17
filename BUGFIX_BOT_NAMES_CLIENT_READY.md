# Bug Fixes: Bot Names & Client-Ready Protocol

## Issues Identified

### Issue 1: Bot Names Showing as IDs
**Symptom**: Game logs and UI show bot identifiers like `bot_b6e1mdbx` instead of friendly names like "Shubham", "Julie", etc.

**Example from logs**:
```
I/flutter (22274): [2026-01-17T07:58:27.265460] SESSION: 🎬 [WebSocket] Last Event: cardsPlayed by bot_b6e1mdbx
```

**Root Cause**: The `pNames` map in `WebSocketSessionHandler` was never being populated with participant names from the game state. When `getPlayerName(id)` was called, it would fall back to returning the ID.

**Fix**: Modified `websocket_message_handler_mixin.dart` to populate the `pNames` map when parsing participants in the `handleGameState` method.

```dart
// ✅ FIX: Populate pNames map for UI display
pNames[participantId] = participantName;
```

### Issue 2: Shuffling Animation Starting Before CLIENT_READY
**Symptom**: The shuffling animation would trigger before the client UI was fully initialized, causing it to be missed.

**Timeline from logs**:
- 07:58:16.386 - Server sends GAME_STATE with phase "thinking" and lastEvent "shuffling" 
- 07:58:17.463 - Client sends CLIENT_READY (1 second later)

**Root Cause**: When the lobby filled up, the game entered `PhaseStarting` with a 15-second countdown timer. This timer would start the game (including shuffling) regardless of whether human clients had sent their CLIENT_READY signals. Bots were marked as ready immediately (line 381-386 in room.go), but the countdown would proceed even if human players hadn't signaled ready yet.

**Fix**: Modified the countdown logic in `room.go` to check if all human players have sent CLIENT_READY before starting the game via the timeout path.

```go
// ✅ FIX: Only start via timeout if we're not actively waiting for CLIENT_READY
// Check if all human players have signaled ready
humanPlayersReady := true
for _, p := range r.game.Players {
    if !p.IsBot && !r.readyClients[p.ID] {
        humanPlayersReady = false
        break
    }
}

if humanPlayersReady {
    // Start game...
} else {
    log.Printf("⏳ [Client-Ready] Room %s countdown expired, but waiting for CLIENT_READY signals", r.ID)
}
```

## How It Works Now

### Client-Ready Flow:
1. **Lobby fills** → Game enters `PhaseStarting`, 15-second countdown begins
2. **Bots** → Immediately marked as ready (lines 381-386)
3. **Clients** → Navigate to SessionScreen
4. **First frame renders** → Client calls `signalClientReady()` (line 82 in session_screen.dart)
5. **CLIENT_READY received** → Server calls `checkAllPlayersReady()` (line 785 in room.go)
6. **All players ready?** → Game starts immediately via `checkAllPlayersReady()`
7. **Countdown expires** → Check if human players are ready
   - If yes: Start game (fallback path)
   - If no: Wait for CLIENT_READY (prevents premature start)

### Name Display:
- When `GAME_STATE` is received, participant names are now stored in `pNames`
- `getPlayerName(id)` returns the actual name instead of falling back to the ID
- Works for both bots ("Shubham", "Julie") and human players

## Testing

To verify these fixes:

1. **Bot Names**: Check game logs and UI to confirm bot names are displayed correctly:
   - Game log should show "Shubham played 2 cards" instead of "bot_b6e1mdbx played 2 cards"
   - Turn popups should show "SHUBHAM'S TURN" instead of "BOT_B6E1MDBX'S TURN"

2. **Client-Ready**: Watch for the shuffling animation:
   - Should NOT see "shuffling started before client ready" in logs
   - Shuffling animation should play smoothly on the SessionScreen
   - Server logs should show: `✅ [Client-Ready] All players ready in room <id>! Starting game now.`

## Files Modified

1. **`lib/core/engine/data/handlers/mixins/websocket_message_handler_mixin.dart`**
   - Added population of `pNames` map in `handleGameState()`

2. **`server/room/room.go`** 
   - Modified countdown timer logic to check CLIENT_READY status before starting
