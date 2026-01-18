package room

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"veil_server/config"
	"veil_server/game"
	"veil_server/internal/domain/match"
	"veil_server/internal/domain/session"
	"veil_server/internal/infrastructure/webrtc"
	"veil_server/protocol"

	pion "github.com/pion/webrtc/v3"
)

// Room represents a single game session (Infrastructure/Actor Layer)
type Room struct {
	mu sync.RWMutex // Protects session access

	ID      string
	session *session.Session
	clients map[*Client]bool

	// Channels (internal use mostly, exposed via methods)
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	actions    chan GameAction
	quit       chan struct{}

	// Timing
	turnTimer    *time.Timer
	turnDuration time.Duration
	gracePeriod  time.Duration

	// Event sequencing for race condition prevention
	eventSequence int64

	// ✅ FIX #3: Track pending challenge timer for cancellation
	pendingChallengeTimer *time.Timer
	startGameTimer        *time.Timer

	// Broadcaster handles message distribution
	broadcaster *Broadcaster

	// Cleanup callback
	OnStop func()

	// Session Expiry Channel (Notify Manager to clean index)
	SessionExpiry chan<- string

	// Dependencies
	manager *Manager

	// Middleware-composed handler
	actionHandler ActionHandler
}

type GameAction struct {
	Client  *Client
	Message protocol.BaseMessage
}

func NewRoom(id string, manager *Manager) *Room {
	settings := session.Settings{
		MaxPlayers: config.DefaultMaxPlayers,
		BootAmount: float64(config.DefaultBootAmount),
	}

	room := &Room{
		ID:           id,
		manager:      manager,
		session:      session.NewSession(id, settings, webrtc.NewManager()),
		broadcast:    make(chan []byte, config.BroadcastChannelBuffer),
		register:     make(chan *Client, config.RegisterChannelBuffer),
		unregister:   make(chan *Client, config.UnregisterChannelBuffer),
		clients:      make(map[*Client]bool),
		actions:      make(chan GameAction, config.ActionsChannelBuffer),
		quit:         make(chan struct{}),
		turnDuration: config.TurnTimeout,
		gracePeriod:  config.DefaultGracePeriod,
	}
	// Initialize broadcaster with reference to this room
	room.broadcaster = NewBroadcaster(room)

	// Compose middleware chain
	room.actionHandler = applyMiddlewares(room.handleActionCore,
		room.AuthMiddleware,
		room.ValidationMiddleware,
		room.RateLimitMiddleware,
	)

	return room
}

func NewPrivateRoom(id, name, code, password, hostID string, maxPlayers int, bootAmount float64, manager *Manager) *Room {
	settings := session.Settings{
		Name:       name,
		Code:       code,
		Password:   password,
		IsPrivate:  true,
		HostID:     hostID,
		MaxPlayers: maxPlayers,
		BootAmount: bootAmount,
	}

	r := &Room{
		ID:           id,
		manager:      manager,
		session:      session.NewSession(id, settings, webrtc.NewManager()),
		broadcast:    make(chan []byte, config.BroadcastChannelBuffer),
		register:     make(chan *Client, config.RegisterChannelBuffer),
		unregister:   make(chan *Client, config.UnregisterChannelBuffer),
		clients:      make(map[*Client]bool),
		actions:      make(chan GameAction, config.ActionsChannelBuffer),
		quit:         make(chan struct{}),
		turnDuration: config.TurnTimeout,
		gracePeriod:  config.DefaultGracePeriod,
	}
	r.broadcaster = NewBroadcaster(r)

	// Compose middleware chain
	r.actionHandler = applyMiddlewares(r.handleActionCore,
		r.AuthMiddleware,
		r.ValidationMiddleware,
		r.RateLimitMiddleware,
	)

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
	defer func() { recover() }()
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
	return r.session.IsFull()
}

func (r *Room) IsPrivate() bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.session.Settings.IsPrivate
}

func (r *Room) CheckPassword(pw string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.session.Settings.Password == "" || r.session.Settings.Password == pw
}

func (r *Room) GetInfo() map[string]interface{} {
	r.mu.RLock()
	defer r.mu.RUnlock()

	s := r.session
	return map[string]interface{}{
		"roomCode":    s.Settings.Code,
		"roomName":    s.Settings.Name,
		"hostId":      s.Settings.HostID,
		"maxPlayers":  s.Settings.MaxPlayers,
		"bootAmount":  s.Settings.BootAmount,
		"playerCount": len(s.Game.Participants),
		"isPrivate":   s.Settings.IsPrivate,
		"createdAt":   s.CreatedAt,
	}
}

func (r *Room) GetUnicastActionChannel(client *Client) chan<- GameAction {
	return r.actions
}

func (r *Room) GetGamePhase() string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return string(r.session.Game.Phase)
}

// SetMaxPlayers allows overriding the default max players (used by matchmaker)
func (r *Room) SetMaxPlayers(max int) {
	// ✅ FIX #11: Add bounds validation
	if max < 2 {
		max = 2
	} else if max > 10 {
		max = 10
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.session.Settings.MaxPlayers = max
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

	s := r.session
	// 1. Check if they are currently connected
	for client := range r.clients {
		if client.ID == playerID {
			return true
		}
	}

	// 2. Check if they are in the game state (participants)
	if _, exists := s.Game.PlayerMap[playerID]; exists {
		return true
	}

	// 3. Check if they are in disconnectTimeout grace period
	if _, exists := s.DisconnectTimes[playerID]; exists {
		return true
	}

	return false
}

func (r *Room) handleTurnTimeout() {
	activeID := r.session.Game.ActivePlayerID()
	if activeID == "" {
		return
	}

	log.Printf("Turn timeout for player %s in room %s", activeID, r.ID)

	// Auto-action based on phase
	switch r.session.Game.Phase {
	case game.PhaseThinking, game.PhaseChallenging:
		r.session.Game.Pass(activeID)
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

		func() {
			defer func() { recover() }() // Ignore panic if send fails on closed channel
			for client := range r.clients {
				select {
				case client.Send <- bytes:
				default:
				}
			}
		}()

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
			s := r.session
			boot := config.DefaultBootAmount
			if s.Settings.IsPrivate {
				boot = int(s.Settings.BootAmount)
			}

			// ✅ FIX #1: Check coins BEFORE locking to avoid unlock/relock race condition
			// Pre-check: Validate coins without deducting (matchmaker already validated, this is backup)
			isRejoining := false
			r.mu.Lock()
			if _, disconnected := s.DisconnectTimes[client.ID]; disconnected {
				isRejoining = true
				delete(s.DisconnectTimes, client.ID)
				log.Printf("Client %s rejoined room %s within grace period.", client.ID, r.ID)
			}

			// Only deduct coins if not rejoining, not spectator, not bot
			if !isRejoining && !client.IsSpectator && !client.IsBot {
				// ✅ Use buffered coin update - deferred async deduction
				// This avoids the dangerous unlock/relock pattern
				r.manager.economyUC.BufferCoinUpdate(client.ID, -boot)
			}

			// 2. In-memory updates (lock is held)
			r.clients[client] = true
			log.Printf("Client joined Room %s (Spectator: %v)", r.ID, client.IsSpectator)

			if !client.IsSpectator {
				// Use client's stored name and avatar (synced during AUTH)
				playerName := game.DefaultPlayerName(client.ID, client.Name)
				if err := s.Game.AddPlayer(client.ID, playerName, client.AvatarURL, client.IsBot); err != nil {
					log.Printf("Error adding player %s to game in room %s: %v", client.ID, r.ID, err)
					// Refund if add fails
					if !client.IsBot && !isRejoining {
						r.manager.economyUC.BufferCoinUpdate(client.ID, boot) // Async refund
					}
				} else {
					log.Printf("Player %s successfully added to game in room %s. Players: %d/%d",
						client.ID, r.ID, len(s.Game.Players), s.Settings.MaxPlayers)
				}

				// Check auto-start for public rooms
				if !s.Settings.IsPrivate && len(s.Game.Players) >= s.Settings.MaxPlayers && s.Game.Phase == game.PhaseLobby {
					// ✅ UPDATED: Wait for CLIENT_READY signal from all players
					// Use configured delay as a fallback timeout
					log.Printf("Lobby full in room %s. Starting %ds fallback countdown...", r.ID, config.LobbyStartDelaySec)
					s.Game.Phase = game.PhaseStarting
					s.Game.StartTime = time.Now().Unix() + int64(config.LobbyStartDelaySec)

					// Pre-mark all Bots as ready immediately
					for _, p := range s.Game.Players {
						if p.IsBot {
							s.ReadyClients[p.ID] = true
						}
					}

					// ✅ FIX: Check readiness immediately (in case all players are bots or already ready)
					r.checkAllPlayersReady()
				}
			}

			// Broadcast Update
			if s.Settings.IsPrivate {
				r.broadcaster.BroadcastRoomInfoLocked()
			}
			// Always broadcast state so clients receive hand/game data
			r.broadcaster.BroadcastStateLocked()
			r.mu.Unlock()

		case client := <-r.unregister:
			r.mu.Lock()
			s := r.session
			if _, ok := r.clients[client]; ok {
				delete(r.clients, client)
				s.Voice.ReleaseMic(client.ID)
				log.Printf("Client left Room %s", r.ID)

				// ✅ FIX #14: Handle PhaseStarting like PhaseLobby (immediate removal)
				// If game is ACTIVE (Thinking, Challenging, Revealing), mark as disconnected
				if s.Game.IsActive() {
					s.DisconnectTimes[client.ID] = time.Now()
					log.Printf("Player %s disconnected during active game. Grace period started.", client.ID)
					// Update player status in game state
					if player := s.Game.PlayerMap[client.ID]; player != nil {
						player.IsDisconnected = true
					}
				} else {
					// If in Lobby, Starting, or Finished phase - remove immediately
					s.Game.RemovePlayer(client.ID)
					delete(s.DisconnectTimes, client.ID) // Ensure they are not in disconnectTimes

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
				if s.Settings.IsPrivate && client.ID == s.Settings.HostID {
					if len(s.Game.Players) > 0 {
						// Assign first player as host
						s.Settings.HostID = s.Game.Players[0].ID
					}
				}

				if s.Settings.IsPrivate {
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
			if r.session.Voice.Tick() {
				r.session.WebRTC.SetSpeaker(r.session.Voice.CurrentSpeakerID)
				r.broadcaster.BroadcastVoiceStateLocked()
			}

			// Check Countdown Start
			if r.session.Game.Phase == game.PhaseStarting {
				if time.Now().Unix() >= r.session.Game.StartTime {
					// Timeout reached: Force start regardless of explicit ready signals
					// (The early start optimization is handled in checkAllPlayersReady)
					log.Printf("Countdown finished in Room %s. Starting game!", r.ID)
					if err := r.session.Game.Start(); err != nil {
						log.Printf("Failed to start game after countdown: %v", err)
						r.session.Game.Phase = game.PhaseLobby
					}
					r.broadcaster.BroadcastStateLocked()
				}
			}

			// Turn Timeout Check (Every 1s)
			if tickCount == 0 && (r.session.Game.Phase == game.PhaseThinking || r.session.Game.Phase == game.PhaseChallenging) {
				if r.session.Game.TurnStartTime > 0 {
					elapsed := time.Now().Unix() - r.session.Game.TurnStartTime
					if elapsed > config.TurnTimeoutSec {
						r.handleTurnTimeout()
					}
				}
			}

			// ✅ FIX: Process Bot Turns
			// Check every tick (200ms) but strict throttled by TurnStartTime
			if r.session.Game.Phase == game.PhaseThinking || r.session.Game.Phase == game.PhaseChallenging {
				activeID := r.session.Game.ActivePlayerID()
				if player := r.session.Game.PlayerMap[activeID]; player != nil && player.IsBot {
					// Add delay so bot doesn't play instantly (human-like)
					if time.Now().Unix() >= r.session.Game.TurnStartTime+config.BotThinkingDelaySec {
						r.processBotMove(player)
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
			humanCount += len(r.session.DisconnectTimes)

			// ✅ FIX #5: If NO humans are left (connected or waiting), stop the room immediately
			// This prevents ghost rooms with only bots running forever.
			if humanCount == 0 && r.session.Game.Phase != game.PhaseLobby {
				log.Printf("Room %s: No humans left. Closing room.", r.ID)
				r.mu.Unlock() // Must unlock before returning!
				r.Stop()
				return
			}

			for pid, disconnectTime := range r.session.DisconnectTimes {
				if now.Sub(disconnectTime) > r.gracePeriod {
					log.Printf("Player %s grace period expired in room %s. Removing permanently.", pid, r.ID)
					r.session.Game.RemovePlayer(pid)
					delete(r.session.DisconnectTimes, pid)
					r.broadcaster.BroadcastRoomInfoLocked()
				}
			}

			// HYBRID APPROACH: Periodic Full State Sync (configured interval during active game)
			if r.session.Game.Phase != game.PhaseLobby && r.session.Game.Phase != game.PhaseFinished {
				if now.Sub(r.session.LastFullSync) >= config.PeriodicSyncInterval {
					r.session.LastFullSync = now

					// ✅ Anti-Cheat: Verify deck consistency during sync
					if err := r.session.Game.VerifyDeckConsistency(); err != nil {
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
	// Call composed handler (applies middlewares + core logic)
	r.actionHandler(action)
}

func (r *Room) handleActionCore(action GameAction) {
	s := r.session
	client := action.Client
	msg := action.Message

	// Delegate core logic to Domain Session
	result := r.session.HandleAction(client.ID, msg)
	if result.Error != nil {
		r.sendErrorToClient(client, protocol.ErrCodeGameError, result.Error.Error())
		return
	}

	// 5. Infrastructure-specific side effects
	switch msg.Type {
	case protocol.MsgTypeChallenge:
		if result.BroadcastState {
			r.broadcaster.BroadcastStateLocked()
			// ✅ FIX #3: Use tracked timer so it can be cancelled on room stop
			if r.pendingChallengeTimer != nil {
				r.pendingChallengeTimer.Stop()
			}

			// Capture values for closure
			challengerID := client.ID
			roomID := r.ID
			// s is already defined at top of function

			// Schedule resolution after configured animation delay
			r.pendingChallengeTimer = time.AfterFunc(config.ChallengeRevealDelay, func() {
				r.mu.Lock()
				defer r.mu.Unlock()
				r.pendingChallengeTimer = nil

				if s.Game.Phase != game.PhaseRevealing || len(s.Game.Players) == 0 {
					return
				}

				if s.Game.Phase == game.PhaseRevealing {
					msg := s.Game.ResolveChallenge(challengerID)
					log.Printf("Challenge Resolved in Room %s: %s", roomID, msg)

					if err := s.Game.VerifyDeckConsistency(); err != nil {
						log.Printf("CRITICAL ALERT: Anti-Cheat triggered in Room %s: %v", roomID, err)
					}
				}
				r.broadcaster.BroadcastStateLocked()
			})
			return
		}

	case protocol.MsgTypeVoiceHandRaise, protocol.MsgTypeVoiceSDP, protocol.MsgTypeVoiceICE:
		if !config.GetFeatureFlags().EnableVoiceChat {
			log.Printf("Voice chat is disabled on this server, ignoring message from %s", client.ID)
			return
		}
		switch msg.Type {
		case protocol.MsgTypeVoiceHandRaise:
			isQueued := false
			for _, id := range s.Voice.Queue {
				if id == client.ID {
					isQueued = true
					break
				}
			}
			if s.Voice.CurrentSpeakerID == client.ID || isQueued {
				s.Voice.ReleaseMic(client.ID)
			} else {
				s.Voice.RequestMic(client.ID)
			}
			r.broadcaster.BroadcastVoiceStateLocked()

		case protocol.MsgTypeVoiceSDP:
			var offer pion.SessionDescription
			if json.Unmarshal(msg.Data, &offer) == nil {
				answer, err := s.WebRTC.HandleOffer(client.ID, offer)
				if err == nil && answer != nil {
					resp := protocol.NewMessage(protocol.MsgTypeVoiceSDP, answer)
					bytes, _ := json.Marshal(resp)
					client.Send <- bytes
				}
			}

		case protocol.MsgTypeVoiceICE:
			var candidate pion.ICECandidateInit
			if json.Unmarshal(msg.Data, &candidate) == nil {
				if err := s.WebRTC.HandleICE(client.ID, candidate); err != nil {
					log.Printf("WebRTC ICE Error for %s: %v", client.ID, err)
				}
			}
		}
		return

	case protocol.MsgTypeClientReady:
		log.Printf("Client %s signaled ready in room %s", client.ID, r.ID)
		r.session.ReadyClients[client.ID] = true
		r.checkAllPlayersReady()
		return

	case protocol.MsgTypeLeaveRoom:
		// Index cleanup also needed in infrastructure
		r.manager.RemovePlayerRoom(client.ID)
		// result.BroadcastState handles the state update

	case protocol.MsgTypePlayCards:
		// Anti-cheat check
		if err := r.session.Game.VerifyDeckConsistency(); err != nil {
			log.Printf("CRITICAL ALERT: Anti-Cheat triggered in Room %s: %v", r.ID, err)
		}
	}

	// 6. Handle Results (Broadcasts)
	if result.BroadcastEvent != nil {
		r.broadcaster.BroadcastActionLocked(result.BroadcastEvent.Type, result.BroadcastEvent.Payload.(map[string]interface{}))
	}
	if result.BroadcastState {
		r.broadcaster.BroadcastStateLocked()
	}

	// 7. Check Game Over (Metadata Persistence)
	if s.Game.Phase == game.PhaseFinished {
		log.Printf("Game Over in Room %s! Winner: %s", r.ID, s.Game.WinnerID)

		boot := 100
		if s.Settings.IsPrivate {
			boot = int(s.Settings.BootAmount)
		}
		potAmount := boot * len(s.Game.Participants)

		var playerIDs []string
		statsMap := make(map[string]interface{})
		for _, p := range s.Game.Players {
			playerIDs = append(playerIDs, p.ID)
			statsMap[p.ID] = p.Stats
		}
		matchID := fmt.Sprintf("%s_%d", r.ID, time.Now().Unix())
		winnerID := s.Game.WinnerID
		duration := 0
		if s.Game.StartTime > 0 {
			duration = int(time.Now().Unix() - s.Game.StartTime)
		}

		go func(mid string, pids []string, wid string, pot int, dur int, stats map[string]interface{}) {
			result := match.MatchResult{
				MatchID:     mid,
				PlayerIDs:   pids,
				WinnerID:    wid,
				DurationSec: dur,
				PotAmount:   pot,
				EndedAt:     time.Now(),
				Metadata:    stats,
			}
			if err := r.manager.gameUC.RecordMatchResult(result); err != nil {
				log.Printf("Background: Failed to record game result: %v", err)
			}
		}(matchID, playerIDs, winnerID, potAmount, duration, statsMap)

		r.broadcaster.BroadcastStatsLocked()
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
	errBytes, _ := json.Marshal(protocol.NewErrorMessage(code, message))
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

	s := r.session
	// Access game safely (lock held in caller)
	pile := s.Game.Pile // ✅ Corrected for updated Game struct

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

		if s.Game.DeclaredRank != nil {
			rankToBeat = *s.Game.DeclaredRank // ✅ Corrected pointer access
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
		err := s.Game.PlayCards(bot.ID, cardsToPlay, rankToDeclare)
		if err == nil {
			r.broadcaster.BroadcastActionLocked("PLAY_CARDS", map[string]interface{}{
				"playerId":           bot.ID,
				"count":              len(cardsToPlay),
				"declaredRank":       rankToDeclare,
				"newPileCount":       s.Game.PileCount,
				"nextPlayerId":       s.Game.ActivePlayerID(),
				"playerNewCardCount": len(bot.Hand),
				"turnStartTime":      s.Game.TurnStartTime,
			})
			r.broadcaster.BroadcastStateLocked()
			return
		} else {
			log.Printf("🤖 Bot Play Failed: %v", err)
		}
	}

	// Default: Pass
	log.Printf("🤖 Bot %s passing", bot.Name)
	err := s.Game.Pass(bot.ID)
	if err == nil {
		if s.Game.LastEvent == "pileDiscarded" {
			r.broadcaster.BroadcastStateLocked()
		} else {
			r.broadcaster.BroadcastActionLocked("PASS", map[string]interface{}{
				"playerId":      bot.ID,
				"nextPlayerId":  s.Game.ActivePlayerID(),
				"turnStartTime": s.Game.TurnStartTime,
			})
		}
	}
}

// checkAllPlayersReady checks if all players have signaled ready and starts the game
// This is called after a client sends CLIENT_READY message
func (r *Room) checkAllPlayersReady() {
	s := r.session
	// Only applicable during PhaseStarting
	if s.Game.Phase != game.PhaseStarting {
		return
	}

	// Check if all players (non-spectators) are ready
	totalPlayers := len(s.Game.Players)
	readyCount := 0

	for _, player := range s.Game.Players {
		if s.ReadyClients[player.ID] || player.IsBot {
			readyCount++
		}
	}

	log.Printf("[Client-Ready] Room %s: %d/%d players ready", r.ID, readyCount, totalPlayers)
	// DEBUG: Log who is not ready
	if readyCount < totalPlayers {
		for _, player := range s.Game.Players {
			if !s.ReadyClients[player.ID] {
				log.Printf("   -> Waiting for: %s (Bot: %v)", player.ID, player.IsBot)
			}
		}
	}

	// If all players are ready, start immediately
	if readyCount >= totalPlayers {
		log.Printf("✅ [Client-Ready] All players ready in room %s! Starting game now.", r.ID)

		// Cancel timeout timer if it exists
		if r.startGameTimer != nil {
			r.startGameTimer.Stop()
			r.startGameTimer = nil
		}

		// Start the game
		if err := s.Game.Start(); err != nil {
			log.Printf("Failed to start game after all ready: %v", err)
			s.Game.Phase = game.PhaseLobby
		} else {
			log.Printf("🎮 Game started in room %s (all clients ready)", r.ID)
		}
		r.broadcaster.BroadcastStateLocked()

		// Clear ready tracking for next game
		s.ReadyClients = make(map[string]bool)
	}
}
