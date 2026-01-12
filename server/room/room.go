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

	// Broadcaster handles message distribution
	broadcaster *Broadcaster
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
		turnDuration:    25 * time.Second, // 20s + buffer
		gracePeriod:     30 * time.Second,
		disconnectTimes: make(map[string]time.Time),
		lastFullSync:    time.Now(), // Initialize for periodic sync
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
		close(r.quit)
	}
}

func (r *Room) Leave(client *Client) {
	r.unregister <- client
}

func (r *Room) HandleAction(action GameAction) {
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

func (r *Room) handleTurnTimeout() {
	r.mu.Lock()
	defer r.mu.Unlock()

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

	r.broadcastState()
}

func (r *Room) Run() {
	ticker := time.NewTicker(200 * time.Millisecond)
	tickCount := 0
	defer func() {
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
		log.Printf("Room %s Run loop stopped", r.ID)
	}()

	for {
		select {
		case <-r.quit:
			log.Printf("Room %s received quit signal. Stopping.", r.ID)
			return

		case client := <-r.register:
			// 1. Perform I/O (Deduct coins) BEFORE locking the room
			var joinErr error
			boot := 100 // Default public stake
			if r.isPrivate {
				boot = int(r.bootAmount)
			}

			r.mu.Lock() // Lock early to check disconnectTimes
			// If a player rejoins within the grace period, remove them from disconnectTimes
			if _, disconnected := r.disconnectTimes[client.ID]; disconnected {
				delete(r.disconnectTimes, client.ID)
				log.Printf("Client %s rejoined room %s within grace period.", client.ID, r.ID)
				// No coin deduction needed if rejoining
			} else {
				// Only deduct coins if not rejoining
				if !client.IsSpectator && !client.IsBot {
					r.mu.Unlock() // Unlock temporarily for DB call
					joinErr = db.UpdateUserCoins(client.ID, -boot)
					r.mu.Lock() // Relock
					if joinErr != nil {
						log.Printf("Cannot join room: Insufficient funds for %s: %v", client.ID, joinErr)
						r.sendErrorToClient(client, "INSUFFICIENT_FUNDS", "Not enough coins to join")
						r.mu.Unlock()
						continue // Drop this registration attempt
					}
				}
			}

			// 2. Now take the lock for in-memory updates
			r.clients[client] = true
			log.Printf("Client joined Room %s (Spectator: %v)", r.ID, client.IsSpectator)

			if !client.IsSpectator {
				// We already deducted coins above, now just add to game
				name := client.Name
				if name == "" {
					name = "Player " + client.ID
				}
				// Use client's stored name and avatar (synced during AUTH)
				if err := r.game.AddPlayer(client.ID, client.Name, client.AvatarURL); err != nil {
					log.Printf("Error adding player %s to game in room %s: %v", client.ID, r.ID, err)
					// Refund if add fails (Note: This is still I/O inside a lock, but failing here is rare)
					if !client.IsBot {
						db.BufferCoinUpdate(client.ID, boot) // Use buffer for asynchronous refund
					}
				} else {
					log.Printf("Player %s successfully added to game in room %s. Players: %d/%d",
						client.ID, r.ID, len(r.game.Players), r.maxPlayers)
				}

				// Check auto-start for public rooms
				if !r.isPrivate && len(r.game.Players) >= r.maxPlayers && r.game.Phase == game.PhaseLobby {
					log.Printf("Lobby full in room %s. Starting %ds countdown...", r.ID, game.StartGameDelayS)
					r.game.Phase = game.PhaseStarting
					r.game.StartTime = time.Now().Unix() + int64(game.StartGameDelayS)
				}
			}

			// Broadcast Update
			if r.isPrivate {
				r.broadcastRoomInfo()
			} else {
				r.broadcaster.BroadcastState()
			}
			r.mu.Unlock()

		case client := <-r.unregister:
			r.mu.Lock()
			if _, ok := r.clients[client]; ok {
				delete(r.clients, client)
				r.voice.ReleaseMic(client.ID)
				log.Printf("Client left Room %s", r.ID)

				// If game is active, mark as disconnected, don't remove immediately
				if r.game.Phase != game.PhaseLobby && r.game.Phase != game.PhaseFinished {
					r.disconnectTimes[client.ID] = time.Now()
					log.Printf("Player %s disconnected during active game. Grace period started.", client.ID)
					// Update player status in game state
					if p := r.game.PlayerMap[client.ID]; p != nil {
						p.IsDisconnected = true
					}
				} else {
					// If in lobby or game finished, remove player immediately
					r.game.RemovePlayer(client.ID)
					delete(r.disconnectTimes, client.ID) // Ensure they are not in disconnectTimes
				}

				// Host reassignment
				if r.isPrivate && client.ID == r.hostID {
					if len(r.game.Players) > 0 {
						// Assign first player as host
						r.hostID = r.game.Players[0].ID
					}
				}

				if r.isPrivate {
					r.broadcastRoomInfo()
				} else {
					r.broadcaster.BroadcastState()
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
					close(client.Send)
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
				r.broadcastVoiceState()
			}

			// Check Countdown Start
			if r.game.Phase == game.PhaseStarting {
				if time.Now().Unix() >= r.game.StartTime {
					log.Printf("Countdown finished in Room %s. Starting game!", r.ID)
					if err := r.game.Start(); err != nil {
						log.Printf("Failed to start game after countdown: %v", err)
						r.game.Phase = game.PhaseLobby
					}
					r.broadcaster.BroadcastState()
				}
			}

			// Turn Timeout Check (Every 1s)
			if tickCount == 0 && (r.game.Phase == game.PhaseThinking || r.game.Phase == game.PhaseChallenging) {
				if r.game.TurnStartTime > 0 {
					elapsed := time.Now().Unix() - r.game.TurnStartTime
					if elapsed > 25 { // 25s limit
						r.handleTurnTimeout()
					}
				}
			}

			// Grace Period Check
			now := time.Now()
			for pid, disconnectTime := range r.disconnectTimes {
				if now.Sub(disconnectTime) > r.gracePeriod {
					log.Printf("Player %s grace period expired in room %s. Removing permanently.", pid, r.ID)
					r.game.RemovePlayer(pid)
					delete(r.disconnectTimes, pid)
					r.broadcastRoomInfo()
				}
			}

			// HYBRID APPROACH: Periodic Full State Sync (every 30s during active game)
			if r.game.Phase != game.PhaseLobby && r.game.Phase != game.PhaseFinished {
				if now.Sub(r.lastFullSync) >= 30*time.Second {
					r.lastFullSync = now
					r.broadcaster.BroadcastState() // Full state resync to prevent drift
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
				r.broadcaster.BroadcastAction("PLAY_CARDS", map[string]interface{}{
					"playerId":           client.ID,
					"count":              len(payload.CardIDs),
					"declaredRank":       payload.DeclaredRank,
					"newPileCount":       r.game.PileCount,
					"nextPlayerId":       r.game.ActivePlayerID(),
					"playerNewCardCount": len(p.Hand), // Fix state drift
				})
				return // Skip default broadcast
			}
		}

	case protocol.MsgTypePass:
		err = r.game.Pass(client.ID)
		if err == nil {
			// Check if pile was discarded (all passed)
			if r.game.LastEvent == "pileDiscarded" {
				// Send full state for round reset
				r.broadcaster.BroadcastState()
			} else {
				// HYBRID: Send lightweight pass event
				r.broadcaster.BroadcastAction("PASS", map[string]interface{}{
					"playerId":     client.ID,
					"nextPlayerId": r.game.ActivePlayerID(),
				})
			}
			return // Skip default broadcast
		}

	case protocol.MsgTypeChallenge:
		_, err = r.game.Challenge(client.ID)
		if err == nil {
			// Broadcast the "Revealing" state immediately
			r.broadcaster.BroadcastState()

			// Schedule resolution after 2 seconds (animation time)
			time.AfterFunc(2*time.Second, func() {
				r.mu.Lock()
				defer r.mu.Unlock()

				// Finalize the result
				msg := r.game.ResolveChallenge(client.ID)
				log.Printf("Challenge Resolved in Room %s: %s", r.ID, msg)

				// Broadcast the final result state
				r.broadcaster.BroadcastState()
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
			r.broadcastVoiceState()

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
		// Valid move -> Already sent event or full state above

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
			r.broadcastStats()
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

// HYBRID APPROACH: Lightweight event broadcasting
// Sends ~150 bytes instead of ~1200 bytes for most actions
func (r *Room) broadcastAction(action string, data map[string]interface{}) {
	// Generate monotonic sequence number (thread-safe due to room.mu lock)
	r.eventSequence++

	msg := protocol.NewMessage(protocol.MsgTypeGameAction, map[string]interface{}{
		"action":    action,
		"data":      data,
		"timestamp": time.Now().Unix(),
		"sequence":  r.eventSequence, // Prevents race condition
	})
	bytes, _ := json.Marshal(msg)
	r.broadcast <- bytes
}

func (r *Room) broadcastStats() {
	// 1. Get client snapshot and release lock quickly
	r.mu.RLock()
	var clients []*Client
	for c := range r.clients {
		clients = append(clients, c)
	}
	r.mu.RUnlock()

	// 2. Perform DB lookups and sends outside the room lock
	for _, client := range clients {
		go func(c *Client) {
			stats, err := db.GetOrCreateUser(c.ID, "") // Name ignored on fetch
			if err == nil {
				msg := protocol.NewMessage("STATS_UPDATE", stats)
				bytes, _ := json.Marshal(msg)
				select {
				case c.Send <- bytes:
				default:
				}
			}
		}(client)
	}
}

func (r *Room) broadcastVoiceState() {
	msg := protocol.NewMessage(protocol.MsgTypeVoiceState, r.voice)
	bytes, _ := json.Marshal(msg)

	for client := range r.clients {
		select {
		case client.Send <- bytes:
		default:
			log.Printf("Skip send voice to %s", client.ID)
		}
	}
}

func (r *Room) broadcastState() {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("Recovered from panic in BroadcastState: %v", err)
		}
	}()

	// OPTIMIZATION: Build shared state once instead of per-client
	sharedState := map[string]interface{}{
		"phase":              r.game.Phase,
		"startTime":          r.game.StartTime,
		"participants":       r.game.Participants,
		"pileCount":          r.game.PileCount,
		"activePlayerId":     r.game.ActivePlayerID(),
		"declaredRank":       r.game.DeclaredRank,
		"lastEvent":          r.game.LastEvent,
		"lastEventId":        r.game.LastEventID,
		"lastEventActorId":   r.game.LastEventActorID,
		"lastEventCardCount": r.game.LastEventCardCount,
		"isBluffSuccessful":  r.game.IsBluffSuccessful,
		"gameLog":            r.game.GameLog,
		"createdAt":          r.CreationTime,
	}

	// Add lastMove if exists
	if r.game.LastMove != nil {
		sharedState["lastMove"] = map[string]interface{}{
			"playerId":     r.game.LastMove.PlayerID,
			"declaredRank": r.game.LastMove.DeclaredRank,
		}
	}

	for client := range r.clients {
		if client.IsSpectator {
			// Spectators get shared state + empty hand
			view := make(map[string]interface{})
			for k, v := range sharedState {
				view[k] = v
			}
			view["myHand"] = []interface{}{}
			view["isSpectator"] = true

			msg := protocol.NewMessage(protocol.MsgTypeGameState, view)
			bytes, _ := json.Marshal(msg)
			select {
			case client.Send <- bytes:
			default:
			}
			continue
		}

		p := r.game.PlayerMap[client.ID]
		if p == nil {
			continue
		}

		r.game.SyncParticipants(client.ID) // Generate personalized view with masked IDs

		// Clone shared state and add personal data
		view := make(map[string]interface{})
		for k, v := range sharedState {
			view[k] = v
		}
		view["myHand"] = p.Hand

		msg := protocol.NewMessage(protocol.MsgTypeGameState, view)
		bytes, _ := json.Marshal(msg)

		select {
		case client.Send <- bytes:
		default:
			log.Printf("Skip send to %s (buffer full/closed)", client.ID)
		}
	}
}

func (r *Room) broadcastRoomInfo() {
	// Build participants list
	var participants []map[string]interface{}
	for client := range r.clients {
		p := map[string]interface{}{
			"id":       client.ID,
			"name":     "Player " + client.ID,
			"isActive": true,
		}
		if r.game.PlayerMap[client.ID] != nil {
			p["name"] = r.game.PlayerMap[client.ID].Name
		}
		participants = append(participants, p)
	}

	roomInfo := map[string]interface{}{
		"roomCode":      r.code,
		"roomName":      r.name,
		"hostId":        r.hostID,
		"maxPlayers":    r.maxPlayers,
		"bootAmount":    r.bootAmount,
		"playerCount":   len(r.clients),
		"createdAt":     r.CreationTime,
		"participants":  participants,
		"isGameStarted": r.game.Phase != game.PhaseLobby,
	}

	// OPTIMIZATION: Serialize once
	msg := protocol.NewMessage(protocol.MsgTypeRoomUpdate, roomInfo)
	bytes, _ := json.Marshal(msg)

	// Broadcast to all clients
	for client := range r.clients {
		select {
		case client.Send <- bytes:
		default:
		}
	}
}

// ForceBroadcastState allows external triggers (e.g. from Manager) to safely broadcast state.
func (r *Room) ForceBroadcastState() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastState()
}
