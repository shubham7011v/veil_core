package room

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"veil_server/config"
	"veil_server/db"
	"veil_server/game"
	"veil_server/protocol"

	"github.com/pion/webrtc/v3"
)

// Room represents a single game session
type Room struct {
	mu sync.RWMutex // Protects state access

	ID           string
	CreationTime int64 // Unix timestamp (seconds) of room creation
	clients      map[*Client]bool

	// Channels (internal use mostly, exposed via methods)
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	actions    chan GameAction
	quit       chan struct{}

	// Timing
	turnTimer       *time.Timer
	turnDuration    time.Duration
	gracePeriod     time.Duration
	disconnectTimes map[string]time.Time // Track when each player disconnected
	lastFullSync    time.Time            // Periodic full state sync (hybrid approach)

	// Game State
	game *game.Game

	// Private Settings
	name       string
	code       string
	password   string
	isPrivate  bool
	hostID     string
	maxPlayers int
	bootAmount float64
	voice      *game.VoiceState
	webRTC     *game.WebRTCManager

	// Event sequencing for race condition prevention
	eventSequence int64

	// ✅ FIX #3: Track pending challenge timer for cancellation
	pendingChallengeTimer *time.Timer

	// Client-Ready Protocol: Track which clients have signaled they're ready for game start
	readyClients   map[string]bool
	startGameTimer *time.Timer

	// Broadcaster handles message distribution
	broadcaster *Broadcaster

	// Cleanup callback
	OnStop func()

	// Session Expiry Channel (Notify Manager to clean index)
	SessionExpiry chan<- string
}

type GameAction struct {
	Client  *Client
	Message protocol.BaseMessage
}

func NewRoom(id string) *Room {
	r := &Room{
		ID:              id,
		CreationTime:    time.Now().Unix(),
		broadcast:       make(chan []byte, 32),
		register:        make(chan *Client, 10),
		unregister:      make(chan *Client, 10),
		clients:         make(map[*Client]bool),
		game:            game.NewGame(),
		actions:         make(chan GameAction, 32),
		quit:            make(chan struct{}),
		maxPlayers:      game.MaxPlayers, // Default
		voice:           game.NewVoiceState(),
		webRTC:          game.NewWebRTCManager(),
		turnDuration:    30 * time.Second, // 30s baseline
		gracePeriod:     60 * time.Second, // ✅ Increased from 30s to 60s for better mobile stability
		disconnectTimes: make(map[string]time.Time),
		lastFullSync:    time.Now(), // Initialize for periodic sync
		readyClients:    make(map[string]bool),
	}
	// Initialize broadcaster with reference to this room
	r.broadcaster = NewBroadcaster(r)
	return r
}

func NewPrivateRoom(id, name, code, password, hostID string, maxPlayers int, bootAmount float64) *Room {
	r := NewRoom(id)
	r.name = name
	r.code = code
	r.password = password
	r.isPrivate = true
	r.hostID = hostID
	r.maxPlayers = maxPlayers
	r.bootAmount = bootAmount
	// Voice/WebRTC already init in NewRoom
	return r
}

// -- Public Accessors (Thread-Safe) --

func (r *Room) Join(client *Client) {
	r.register <- client
}

func (r *Room) Stop() {
	select {
	case <-r.quit:
		// Already stopped
	default:
		// ✅ FIX #3: Cancel any pending challenge timer
		r.mu.Lock()
		if r.pendingChallengeTimer != nil {
			r.pendingChallengeTimer.Stop()
			r.pendingChallengeTimer = nil
		}
		r.mu.Unlock()
		close(r.quit)
	}
}

func (r *Room) Leave(client *Client) {
	r.unregister <- client
}

func (r *Room) HandleAction(action GameAction) {
	defer func() {
		if rec := recover(); rec != nil {
			log.Printf("Warn: Dropped action from %s because room %s is closed (recovered: %v)", action.Client.ID, r.ID, rec)
		}
	}()

	// Check if room is effectively closed to avoid panic where possible
	select {
	case <-r.quit:
		return
	default:
	}

	r.actions <- action
}

func (r *Room) IsFull() bool {
	r.mu.RLock()
	defer r.mu.RUnlock()

	// Count non-spectator clients directly to avoid race conditions
	// between client registration and participant creation
	playerCount := 0
	for client := range r.clients {
		if !client.IsSpectator {
			playerCount++
		}
	}

	return playerCount >= r.maxPlayers
}

func (r *Room) IsPrivate() bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.isPrivate
}

func (r *Room) CheckPassword(pw string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.password == "" || r.password == pw
}

func (r *Room) GetInfo() map[string]interface{} {
	r.mu.RLock()
	defer r.mu.RUnlock()

	return map[string]interface{}{
		"roomCode":    r.code,
		"roomName":    r.name,
		"hostId":      r.hostID,
		"maxPlayers":  r.maxPlayers,
		"bootAmount":  r.bootAmount,
		"playerCount": len(r.game.Participants),
		"isPrivate":   r.isPrivate,
		"createdAt":   r.CreationTime,
	}
}

func (r *Room) GetUnicastActionChannel(client *Client) chan<- GameAction {
	return r.actions
}

func (r *Room) GetGamePhase() string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return string(r.game.Phase)
}

// SetMaxPlayers allows overriding the default max players (used by matchmaker)
func (r *Room) SetMaxPlayers(max int) {
	// ✅ FIX #11: Add bounds validation
	if max < 2 {
		max = 2
	} else if max > 10 {
		max = 10
	}
	r.maxPlayers = max
}

func (r *Room) GetClientCount() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.clients)
}

func (r *Room) GetPlayerIDs() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var ids []string
	for client := range r.clients {
		ids = append(ids, client.ID)
	}
	return ids
}

// IsPlayerInRoom checks if a player ID is part of the game or currently disconnected but within grace period
func (r *Room) IsPlayerInRoom(playerID string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()

	// 1. Check if they are currently connected
	for client := range r.clients {
		if client.ID == playerID {
			return true
		}
	}

	// 2. Check if they are in the game state (participants)
	if _, exists := r.game.PlayerMap[playerID]; exists {
		return true
	}

	// 3. Check if they are in disconnectTimeout grace period
	if _, exists := r.disconnectTimes[playerID]; exists {
		return true
	}

	return false
}

func (r *Room) handleTurnTimeout() {
	// LOCK REMOVED: Called from Run() loop which already holds r.mu.Lock()
	// Doing r.mu.Lock() here caused a deadlock.

	activeID := r.game.ActivePlayerID()
	if activeID == "" {
		return
	}

	log.Printf("Turn timeout for player %s in room %s", activeID, r.ID)

	// Auto-action based on phase
	switch r.game.Phase {
	case game.PhaseThinking, game.PhaseChallenging:
		r.game.Pass(activeID)
	}

	r.broadcaster.BroadcastStateLocked()
}

func (r *Room) Run() {
	ticker := time.NewTicker(200 * time.Millisecond)
	tickCount := 0
	defer func() {
		if rec := recover(); rec != nil {
			log.Printf("CRITICAL: Room %s panicked: %v. Sending cleanup signal.", r.ID, rec)
			// Ensure we don't just exit silently on panic, though the defer block continues below
		}

		// NOTIFY CLIENTS: Room is shutting down
		msg := protocol.NewMessage(protocol.MsgTypeError, map[string]interface{}{
			"code":    "ROOM_CLOSED",
			"message": "The game room has been closed.",
		})
		bytes, _ := json.Marshal(msg)
		for client := range r.clients {
			select {
			case client.Send <- bytes:
			default:
			}
		}

		ticker.Stop()
		close(r.register)
		close(r.unregister)
		close(r.actions)

		if r.OnStop != nil {
			r.OnStop()
		}

		log.Printf("Room %s Run loop stopped", r.ID)
	}()

	for {
		select {
		case <-r.quit:
			log.Printf("Room %s received quit signal. Stopping.", r.ID)
			return

		case client := <-r.register:
			// 1. Calculate boot amount
			boot := 100 // Default public stake
			if r.isPrivate {
				boot = int(r.bootAmount)
			}

			// ✅ FIX #1: Check coins BEFORE locking to avoid unlock/relock race condition
			// Pre-check: Validate coins without deducting (matchmaker already validated, this is backup)
			isRejoining := false
			r.mu.Lock()
			if _, disconnected := r.disconnectTimes[client.ID]; disconnected {
				isRejoining = true
				delete(r.disconnectTimes, client.ID)
				log.Printf("Client %s rejoined room %s within grace period.", client.ID, r.ID)
			}

			// Only deduct coins if not rejoining, not spectator, not bot
			if !isRejoining && !client.IsSpectator && !client.IsBot {
				// ✅ Use buffered coin update - deferred async deduction
				// This avoids the dangerous unlock/relock pattern
				db.BufferCoinUpdate(client.ID, -boot)
			}

			// 2. In-memory updates (lock is held)
			r.clients[client] = true
			log.Printf("Client joined Room %s (Spectator: %v)", r.ID, client.IsSpectator)

			if !client.IsSpectator {
				name := client.Name
				if name == "" {
					name = "Player " + client.ID
				}
				// Use client's stored name and avatar (synced during AUTH)
				if err := r.game.AddPlayer(client.ID, client.Name, client.AvatarURL); err != nil {
					log.Printf("Error adding player %s to game in room %s: %v", client.ID, r.ID, err)
					// Refund if add fails
					if !client.IsBot && !isRejoining {
						db.BufferCoinUpdate(client.ID, boot) // Async refund
					}
				} else {
					log.Printf("Player %s successfully added to game in room %s. Players: %d/%d",
						client.ID, r.ID, len(r.game.Players), r.maxPlayers)
				}

				// Check auto-start for public rooms
				if !r.isPrivate && len(r.game.Players) >= r.maxPlayers && r.game.Phase == game.PhaseLobby {
					// ✅ UPDATED: Wait for CLIENT_READY signal from all players
					// Use 15s as a fallback timeout, but checkAllPlayersReady() should trigger start earlier
					const startDelay = 15
					log.Printf("Lobby full in room %s. Starting %ds fallback countdown...", r.ID, startDelay)
					r.game.Phase = game.PhaseStarting
					r.game.StartTime = time.Now().Unix() + int64(startDelay)

					// Pre-mark all Bots as ready immediately
					for _, p := range r.game.Players {
						if p.IsBot {
							r.readyClients[p.ID] = true
						}
					}
				}
			}

			// Broadcast Update
			if r.isPrivate {
				r.broadcaster.BroadcastRoomInfoLocked()
			}
			// Always broadcast state so clients receive hand/game data
			r.broadcaster.BroadcastStateLocked()
			r.mu.Unlock()

		case client := <-r.unregister:
			r.mu.Lock()
			if _, ok := r.clients[client]; ok {
				delete(r.clients, client)
				r.voice.ReleaseMic(client.ID)
				log.Printf("Client left Room %s", r.ID)

				// ✅ FIX #14: Handle PhaseStarting like PhaseLobby (immediate removal)
				// If game is ACTIVE (Thinking, Challenging, Revealing), mark as disconnected
				if r.game.Phase == game.PhaseThinking ||
					r.game.Phase == game.PhaseChallenging ||
					r.game.Phase == game.PhaseRevealing {
					r.disconnectTimes[client.ID] = time.Now()
					log.Printf("Player %s disconnected during active game. Grace period started.", client.ID)
					// Update player status in game state
					if p := r.game.PlayerMap[client.ID]; p != nil {
						p.IsDisconnected = true
					}
				} else {
					// If in Lobby, Starting, or Finished phase - remove immediately
					r.game.RemovePlayer(client.ID)
					delete(r.disconnectTimes, client.ID) // Ensure they are not in disconnectTimes

					// Notify Manager to clean up index
					if r.SessionExpiry != nil {
						select {
						case r.SessionExpiry <- client.ID:
						default:
							log.Printf("WARNING: SessionExpiry buffer full for %s", client.ID)
						}
					}
				}

				// Host reassignment
				if r.isPrivate && client.ID == r.hostID {
					if len(r.game.Players) > 0 {
						// Assign first player as host
						r.hostID = r.game.Players[0].ID
					}
				}

				if r.isPrivate {
					r.broadcaster.BroadcastRoomInfoLocked()
				} else {
					r.broadcaster.BroadcastStateLocked()
				}
			}
			r.mu.Unlock()

		case action := <-r.actions:
			r.mu.Lock()
			r.processAction(action)
			r.mu.Unlock()

		case message := <-r.broadcast:
			// Lock for iterating clients
			r.mu.Lock()
			for client := range r.clients {
				select {
				case client.Send <- message:
				default:
					delete(r.clients, client)
				}
			}
			r.mu.Unlock()

		case <-ticker.C:
			r.mu.Lock()
			// Game updates
			tickCount++
			if tickCount >= 5 {
				tickCount = 0
			}

			// Public Lobby Timeout is handled by Manager (checkLobbyTimeout)

			// Voice updates
			if r.voice.Tick() {
				r.webRTC.SetSpeaker(r.voice.CurrentSpeakerID)
				r.broadcaster.BroadcastVoiceStateLocked()
			}

			// Check Countdown Start
			if r.game.Phase == game.PhaseStarting {
				if time.Now().Unix() >= r.game.StartTime {
					log.Printf("Countdown finished in Room %s. Starting game!", r.ID)
					if err := r.game.Start(); err != nil {
						log.Printf("Failed to start game after countdown: %v", err)
						r.game.Phase = game.PhaseLobby
					}
					r.broadcaster.BroadcastStateLocked()
				}
			}

			// Turn Timeout Check (Every 1s)
			if tickCount == 0 && (r.game.Phase == game.PhaseThinking || r.game.Phase == game.PhaseChallenging) {
				if r.game.TurnStartTime > 0 {
					elapsed := time.Now().Unix() - r.game.TurnStartTime
					if elapsed > 30 { // 30s limit
						r.handleTurnTimeout()
					}
				}
			}

			// ✅ FIX: Process Bot Turns
			// Check every tick (200ms) but strict throttled by TurnStartTime
			if r.game.Phase == game.PhaseThinking {
				activeID := r.game.ActivePlayerID()
				if p := r.game.PlayerMap[activeID]; p != nil && p.IsBot {
					// Add delay so bot doesn't play instantly (human-like)
					// Verify TurnStartTime + 10s < Now
					if time.Now().Unix() >= r.game.TurnStartTime+10 { // 10s thinking time
						r.processBotMove(p)
					}
				}
			}

			// Grace Period Check
			now := time.Now()
			humanCount := 0
			for client := range r.clients {
				if !client.IsBot {
					humanCount++
				}
			}
			humanCount += len(r.disconnectTimes)

			// ✅ FIX #5: If NO humans are left (connected or waiting), stop the room immediately
			// This prevents ghost rooms with only bots running forever.
			if humanCount == 0 && r.game.Phase != game.PhaseLobby {
				log.Printf("Room %s: No humans left. Closing room.", r.ID)
				r.mu.Unlock() // Must unlock before returning!
				r.Stop()
				return
			}

			for pid, disconnectTime := range r.disconnectTimes {
				if now.Sub(disconnectTime) > r.gracePeriod {
					log.Printf("Player %s grace period expired in room %s. Removing permanently.", pid, r.ID)
					r.game.RemovePlayer(pid)
					delete(r.disconnectTimes, pid)
					r.broadcaster.BroadcastRoomInfoLocked()
				}
			}

			// HYBRID APPROACH: Periodic Full State Sync (every 30s during active game)
			if r.game.Phase != game.PhaseLobby && r.game.Phase != game.PhaseFinished {
				if now.Sub(r.lastFullSync) >= 30*time.Second {
					r.lastFullSync = now

					// ✅ Anti-Cheat: Verify deck consistency during sync
					if err := r.game.VerifyDeckConsistency(); err != nil {
						log.Printf("CRITICAL ALERT: Anti-Cheat triggered in Room %s: %v", r.ID, err)
						// Optionally: Pause game or flag players
					}

					r.broadcaster.BroadcastStateLocked() // Full state resync to prevent drift
					log.Printf("Room %s: Periodic full state sync", r.ID)
				}
			}
			r.mu.Unlock()
		}
	}
}

func (r *Room) processAction(action GameAction) {
	client := action.Client
	msg := action.Message

	// 1. Validate client is in room
	// r.mu.Lock() is already held by Run()
	if !r.clients[client] {
		log.Printf("Rejected action from non-member client %s in room %s", client.ID, r.ID)
		return
	}

	// 2. Validate message type
	if !isValidGameMessageType(msg.Type) {
		log.Printf("Invalid message type %s from client %s", msg.Type, client.ID)
		r.sendErrorToClient(client, "INVALID_MESSAGE", "Invalid message type")
		return
	}

	// 3. Rate limiting check
	if !client.canPerformAction() {
		log.Printf("Rate limited client %s", client.ID)
		r.sendErrorToClient(client, "RATE_LIMITED", "Too many actions")
		return
	}

	var err error

	switch msg.Type {
	case protocol.MsgTypePlayCards:
		var payload protocol.PlayCardsMessage
		if json.Unmarshal(msg.Data, &payload) == nil {
			err = r.game.PlayCards(client.ID, payload.CardIDs, game.Rank(payload.DeclaredRank))
			if err == nil {
				// HYBRID: Send lightweight event instead of full state
				p := r.game.PlayerMap[client.ID]
				r.broadcaster.BroadcastActionLocked("PLAY_CARDS", map[string]interface{}{
					"playerId":           client.ID,
					"count":              len(payload.CardIDs),
					"declaredRank":       payload.DeclaredRank,
					"newPileCount":       r.game.PileCount,
					"nextPlayerId":       r.game.ActivePlayerID(),
					"playerNewCardCount": len(p.Hand),          // Fix state drift
					"turnStartTime":      r.game.TurnStartTime, // CRITICAL: Include timer
				})

				// ✅ Anti-Cheat check after play
				if err := r.game.VerifyDeckConsistency(); err != nil {
					log.Printf("CRITICAL ALERT: Anti-Cheat triggered after PlayCards in Room %s: %v", r.ID, err)
				}
				// Fall through to broadcast full state
			}
		}

	case protocol.MsgTypePass:
		err = r.game.Pass(client.ID)
		if err == nil {
			// Check if pile was discarded (all passed)
			if r.game.LastEvent == "pileDiscarded" {
				// Send full state for round reset
				r.broadcaster.BroadcastStateLocked()
			} else {
				// HYBRID: Send lightweight pass event
				r.broadcaster.BroadcastActionLocked("PASS", map[string]interface{}{
					"playerId":      client.ID,
					"nextPlayerId":  r.game.ActivePlayerID(),
					"turnStartTime": r.game.TurnStartTime, // CRITICAL: Include timer
				})
			}
			// Fall through to broadcast full state
		}

	case protocol.MsgTypeChallenge:
		_, err = r.game.Challenge(client.ID)
		if err == nil {
			// Broadcast the "Revealing" state immediately
			r.broadcaster.BroadcastStateLocked()

			// ✅ FIX #3: Use tracked timer so it can be cancelled on room stop
			// Cancel any existing pending timer first
			if r.pendingChallengeTimer != nil {
				r.pendingChallengeTimer.Stop()
			}

			// Capture values for closure
			challengerID := client.ID
			roomID := r.ID

			// Schedule resolution after 2 seconds (animation time)
			r.pendingChallengeTimer = time.AfterFunc(2*time.Second, func() {
				r.mu.Lock()
				defer r.mu.Unlock()

				// Clear the timer reference
				r.pendingChallengeTimer = nil

				// Safety: Check if game is still in revealing phase and has players
				if r.game.Phase != game.PhaseRevealing || len(r.game.Players) == 0 {
					log.Printf("Challenge resolution skipped in Room %s (phase: %s, players: %d)",
						roomID, r.game.Phase, len(r.game.Players))
					return
				}

				// Finalize the result
				if r.game.Phase == game.PhaseRevealing {
					msg := r.game.ResolveChallenge(challengerID)
					log.Printf("Challenge Resolved in Room %s: %s", roomID, msg)

					// ✅ Anti-Cheat check after resolution
					if err := r.game.VerifyDeckConsistency(); err != nil {
						log.Printf("CRITICAL ALERT: Anti-Cheat triggered after ResolveChallenge in Room %s: %v", roomID, err)
					}
				}

				// Broadcast the final result state
				r.broadcaster.BroadcastStateLocked()
			})
			return // skip r.broadcastState() below to avoid double call
		}

	case protocol.MsgTypeJoinPrivateRoom:
		// Logic mostly handled in Manager.
		// If we did need it here, we'd process it.

	case protocol.MsgTypeVoiceHandRaise, protocol.MsgTypeVoiceSDP, protocol.MsgTypeVoiceICE:
		if !config.GetFeatureFlags().EnableVoiceChat {
			log.Printf("Voice chat is disabled on this server, ignoring message from %s", client.ID)
			return
		}

		switch msg.Type {
		case protocol.MsgTypeVoiceHandRaise:
			isQueued := false
			for _, id := range r.voice.Queue {
				if id == client.ID {
					isQueued = true
					break
				}
			}

			if r.voice.CurrentSpeakerID == client.ID || isQueued {
				r.voice.ReleaseMic(client.ID)
			} else {
				r.voice.RequestMic(client.ID)
			}
			r.broadcaster.BroadcastVoiceStateLocked()

		case protocol.MsgTypeVoiceSDP:
			var offer webrtc.SessionDescription
			if json.Unmarshal(msg.Data, &offer) == nil {
				answer, err := r.webRTC.HandleOffer(client.ID, offer)
				if err == nil && answer != nil {
					resp := protocol.NewMessage(protocol.MsgTypeVoiceSDP, answer)
					bytes, _ := json.Marshal(resp)
					client.Send <- bytes
				} else {
					log.Printf("WebRTC Offer Error for %s: %v", client.ID, err)
				}
			}

		case protocol.MsgTypeVoiceICE:
			var candidate webrtc.ICECandidateInit
			if json.Unmarshal(msg.Data, &candidate) == nil {
				if err := r.webRTC.HandleICE(client.ID, candidate); err != nil {
					log.Printf("WebRTC ICE Error for %s: %v", client.ID, err)
				}
			}
		}

	case protocol.MsgTypeStartGame, protocol.MsgTypeStartPrivateGame:
		if r.game.Phase == game.PhaseLobby {
			// For private rooms, only host can start
			if r.isPrivate && client.ID != r.hostID {
				err = fmt.Errorf("only host can start the game")
			} else {
				err = r.game.Start()
				if err == nil {
					log.Printf("Game started manually in room %s by %s", r.ID, client.ID)
				}
			}
		}

	case protocol.MsgTypeChat:
		var payload protocol.ChatMessage
		if json.Unmarshal(msg.Data, &payload) == nil {
			// Broadcast chat to all
			// We wrap it in a new message with sender info
			out := map[string]interface{}{
				"senderId": client.ID,
				"message":  payload.Message,
				"time":     time.Now().Unix(),
			}
			// Add Sender Name if available
			if p := r.game.PlayerMap[client.ID]; p != nil {
				out["senderName"] = p.Name
			} else {
				out["senderName"] = "Player " + client.ID
			}

			response := protocol.NewMessage(protocol.MsgTypeChat, out)
			bytes, _ := json.Marshal(response)
			r.broadcast <- bytes
		}

	case protocol.MsgTypeEmoji:
		var payload protocol.EmojiMessage
		if json.Unmarshal(msg.Data, &payload) == nil {
			// Broadcast emoji to all
			out := map[string]interface{}{
				"senderId": client.ID,
				"emojiId":  payload.EmojiID,
			}
			response := protocol.NewMessage(protocol.MsgTypeEmoji, out)
			bytes, _ := json.Marshal(response)
			r.broadcast <- bytes
		}

	case protocol.MsgTypeClientReady:
		// Client has signaled their UI is ready for game start
		log.Printf("Client %s signaled ready in room %s", client.ID, r.ID)
		r.readyClients[client.ID] = true

		// Check if all players are ready
		r.checkAllPlayersReady()
		return // No broadcast needed

	case protocol.MsgTypeTyping:
		var payload protocol.TypingMessage
		if json.Unmarshal(msg.Data, &payload) == nil {
			// Broadcast typing status to all
			out := map[string]interface{}{
				"senderId": client.ID,
				"isTyping": payload.IsTyping,
			}
			response := protocol.NewMessage(protocol.MsgTypeTyping, out)
			bytes, _ := json.Marshal(response)
			r.broadcast <- bytes
		}

	case protocol.MsgTypeLeaveRoom:
		log.Printf("Player %s leaving room %s PERMANENTLY", client.ID, r.ID)
		r.game.RemovePlayer(client.ID)
		delete(r.disconnectTimes, client.ID) // Bypass grace period
		if r.isPrivate {
			r.broadcaster.BroadcastRoomInfoLocked()
		} else {
			r.broadcaster.BroadcastStateLocked()
		}
		return // Action processed
	}

	if err != nil {
		// Send error to specific client
		errBytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeError, protocol.ErrorMessage{
			Code:    "GAME_ERROR",
			Message: err.Error(),
		}))
		select {
		case client.Send <- errBytes:
		default:
		}
	} else {
		// Valid move -> Broadcast full state to ensure all clients are synced on phase and turn
		r.broadcaster.BroadcastStateLocked()

		// Check Game Over
		if r.game.Phase == game.PhaseFinished {
			log.Printf("Game Over in Room %s! Winner: %s", r.ID, r.game.WinnerID)

			// 1. Calculate Pot
			// Pot = BootAmount * Number of Players (who actually played)
			boot := 100
			if r.isPrivate {
				boot = int(r.bootAmount)
			}
			potAmount := boot * len(r.game.Participants)

			// 2. Record in SQLite (Moved to goroutine to prevent blocking room lock)
			var playerIDs []string
			for _, p := range r.game.Participants {
				playerIDs = append(playerIDs, p.ID)
			}
			matchID := fmt.Sprintf("%s_%d", r.ID, time.Now().Unix())
			winnerID := r.game.WinnerID

			go func(mid string, pids []string, wid string, pot int) {
				if err := db.RecordGameResult(mid, pids, wid, 120, pot); err != nil {
					log.Printf("Background: Failed to record game result: %v", err)
				}
			}(matchID, playerIDs, winnerID, potAmount)

			// 3. Broadcast Updated Stats
			r.broadcaster.BroadcastStatsLocked()
		}
	}
}

func isValidGameMessageType(msgType string) bool {
	validTypes := map[string]bool{
		protocol.MsgTypePlayCards:        true,
		protocol.MsgTypePass:             true,
		protocol.MsgTypeChallenge:        true,
		protocol.MsgTypeVoiceHandRaise:   true,
		protocol.MsgTypeVoiceSDP:         true,
		protocol.MsgTypeVoiceICE:         true,
		protocol.MsgTypeStartGame:        true,
		protocol.MsgTypeStartPrivateGame: true,
		protocol.MsgTypeChat:             true,
		protocol.MsgTypeEmoji:            true,
		protocol.MsgTypeTyping:           true,
		protocol.MsgTypeLeaveRoom:        true,
		protocol.MsgTypeClientReady:      true,
	}
	return validTypes[msgType]
}

func (r *Room) sendErrorToClient(client *Client, code, message string) {
	errBytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeError, protocol.ErrorMessage{
		Code:    code,
		Message: message,
	}))
	select {
	case client.Send <- errBytes:
	default:
		// Client channel full, skip
	}
}

// ForceBroadcastState allows external triggers (e.g. from Manager) to safely broadcast state.
func (r *Room) ForceBroadcastState() {
	r.broadcaster.BroadcastState()
}

func (r *Room) processBotMove(bot *game.Player) {
	log.Printf("🤖 Bot %s (Hand: %d) is thinking...", bot.Name, len(bot.Hand))

	// Simple Bot Strategy:
	// 1. If pile is empty, play lowest single card.
	// 2. If pile has cards, try to beat it with same quantity.
	// 3. Else pass.

	// This is minimal logic for testing; robustness belongs in a dedicated package really.

	// Access game safely (lock held in caller)
	pile := r.game.Pile // ✅ Corrected for updated Game struct

	// Candidates
	hand := bot.Hand

	var cardsToPlay []string
	var rankToDeclare game.Rank

	if len(pile) == 0 {
		// Play lowest single
		if len(hand) > 0 {
			// Find lowest card
			lowest := hand[0]
			for _, c := range hand {
				if game.RankValue(c.Rank) < game.RankValue(lowest.Rank) { // ✅ Corrected with RankValue
					lowest = c
				}
			}
			cardsToPlay = []string{lowest.ID}
			rankToDeclare = lowest.Rank
		}
	} else {
		// Must match count and beat rank
		countNeeded := len(pile)
		var rankToBeat game.Rank

		if r.game.DeclaredRank != nil {
			rankToBeat = *r.game.DeclaredRank // ✅ Corrected pointer access
		}

		// Naive: Try to find N cards of same rank > rankToBeat
		// Map cards by rank
		rankMap := make(map[game.Rank][]game.Card)
		for _, c := range hand {
			rankMap[c.Rank] = append(rankMap[c.Rank], c)
		}

		// Iterate possible ranks higher than current
		currentVal := game.RankValue(rankToBeat)

		// All ranks logic
		allRanks := []game.Rank{
			game.RankTwo, game.RankThree, game.RankFour, game.RankFive,
			game.RankSix, game.RankSeven, game.RankEight, game.RankNine,
			game.RankTen, game.RankJack, game.RankQueen, game.RankKing, game.RankAce,
		}

		for _, rk := range allRanks {
			if game.RankValue(rk) > currentVal {
				if cards, ok := rankMap[rk]; ok {
					if len(cards) >= countNeeded {
						// Take first N
						subset := cards[:countNeeded]
						for _, c := range subset {
							cardsToPlay = append(cardsToPlay, c.ID)
						}
						rankToDeclare = rk
						break
					}
				}
			}
		}
	}

	if len(cardsToPlay) > 0 {
		log.Printf("🤖 Bot %s playing %d cards (Rank: %s)", bot.Name, len(cardsToPlay), rankToDeclare)

		// Use same broadcast logic as processAction
		err := r.game.PlayCards(bot.ID, cardsToPlay, rankToDeclare)
		if err == nil {
			r.broadcaster.BroadcastActionLocked("PLAY_CARDS", map[string]interface{}{
				"playerId":           bot.ID,
				"count":              len(cardsToPlay),
				"declaredRank":       rankToDeclare,
				"newPileCount":       r.game.PileCount,
				"nextPlayerId":       r.game.ActivePlayerID(),
				"playerNewCardCount": len(bot.Hand),
				"turnStartTime":      r.game.TurnStartTime,
			})
			return
		} else {
			log.Printf("🤖 Bot Play Failed: %v", err)
		}
	}

	// Default: Pass
	log.Printf("🤖 Bot %s passing", bot.Name)
	err := r.game.Pass(bot.ID)
	if err == nil {
		if r.game.LastEvent == "pileDiscarded" {
			r.broadcaster.BroadcastStateLocked()
		} else {
			r.broadcaster.BroadcastActionLocked("PASS", map[string]interface{}{
				"playerId":      bot.ID,
				"nextPlayerId":  r.game.ActivePlayerID(),
				"turnStartTime": r.game.TurnStartTime,
			})
		}
	}
}

// checkAllPlayersReady checks if all players have signaled ready and starts the game
// This is called after a client sends CLIENT_READY message
func (r *Room) checkAllPlayersReady() {
	// Only applicable during PhaseStarting
	if r.game.Phase != game.PhaseStarting {
		return
	}

	// Check if all players (non-spectators) are ready
	totalPlayers := len(r.game.Players)
	readyCount := 0

	for _, player := range r.game.Players {
		if r.readyClients[player.ID] {
			readyCount++
		}
	}

	log.Printf("[Client-Ready] Room %s: %d/%d players ready", r.ID, readyCount, totalPlayers)

	// If all players are ready, start immediately
	if readyCount >= totalPlayers {
		log.Printf("✅ [Client-Ready] All players ready in room %s! Starting game now.", r.ID)

		// Cancel timeout timer if it exists
		if r.startGameTimer != nil {
			r.startGameTimer.Stop()
			r.startGameTimer = nil
		}

		// Start the game
		if err := r.game.Start(); err != nil {
			log.Printf("Failed to start game after all ready: %v", err)
			r.game.Phase = game.PhaseLobby
		} else {
			log.Printf("🎮 Game started in room %s (all clients ready)", r.ID)
		}
		r.broadcaster.BroadcastStateLocked()

		// Clear ready tracking for next game
		r.readyClients = make(map[string]bool)
	}
}
