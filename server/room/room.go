package room

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"veil_server/db"
	"veil_server/game"
	"veil_server/protocol"

	"github.com/pion/webrtc/v3"
)

// Room represents a single game session
type Room struct {
	mu sync.RWMutex // Protects state access

	ID      string
	clients map[*Client]bool

	// Channels (internal use mostly, exposed via methods)
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	actions    chan GameAction

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
}

type GameAction struct {
	Client  *Client
	Message protocol.BaseMessage
}

func NewRoom(id string) *Room {
	return &Room{
		ID:         id,
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[*Client]bool),
		game:       game.NewGame(),
		actions:    make(chan GameAction),
		maxPlayers: game.MaxPlayers, // Default
		voice:      game.NewVoiceState(),
		webRTC:     game.NewWebRTCManager(),
	}
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

func (r *Room) Run() {
	ticker := time.NewTicker(200 * time.Millisecond)
	defer func() {
		ticker.Stop()
		close(r.register)
		close(r.unregister)
		close(r.actions)
	}()

	for {
		select {
		case client := <-r.register:
			r.mu.Lock()
			r.clients[client] = true
			log.Printf("Client joined Room %s (Spectator: %v)", r.ID, client.IsSpectator)

			if !client.IsSpectator {
				// 1. Check Balance and Deduct Coins
				// Default boot amount for public matches or private setting
				boot := 100 // Default public stake
				if r.isPrivate {
					boot = int(r.bootAmount)
				}

				// Deduct coins via DB transaction
				if err := db.UpdateUserCoins(client.ID, -boot); err != nil {
					log.Printf("Cannot join room: Insufficient funds for %s", client.ID)
					r.sendErrorToClient(client, "INSUFFICIENT_FUNDS", "Not enough coins to join")
					// Clean up / kick logic would go here ideally
					// For now, just logging - they might join but be 'broke' effectively
				} else {
					// Auto-join game logic
					if err := r.game.AddPlayer(client.ID, "Player "+client.ID); err != nil {
						log.Printf("Error adding player: %v", err)
						// Refund if add fails?
						db.UpdateUserCoins(client.ID, boot)
					}

					// Check auto-start for public rooms
					if !r.isPrivate && len(r.game.Players) == r.maxPlayers && r.game.Phase == game.PhaseLobby {
						r.game.Start()
					}
				}
			}

			// Broadcast Update
			if r.isPrivate {
				r.broadcastRoomInfo()
			} else {
				r.broadcastState()
			}
			r.mu.Unlock()

		case client := <-r.unregister:
			r.mu.Lock()
			if _, ok := r.clients[client]; ok {
				delete(r.clients, client)
				r.game.RemovePlayer(client.ID)
				r.voice.ReleaseMic(client.ID)
				log.Printf("Client left Room %s", r.ID)

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
					r.broadcastState()
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
			if r.game.Phase != game.PhaseLobby && r.game.Phase != game.PhaseFinished {
				// r.game.Tick()
			}

			// Voice updates
			if r.voice.Tick() {
				r.webRTC.SetSpeaker(r.voice.CurrentSpeakerID)
				r.broadcastVoiceState()
			}
			r.mu.Unlock()
		}
	}
}

func (r *Room) processAction(action GameAction) {
	client := action.Client
	msg := action.Message

	// 1. Validate client is in room
	r.mu.RLock()
	if !r.clients[client] {
		r.mu.RUnlock()
		log.Printf("Rejected action from non-member client %s in room %s", client.ID, r.ID)
		return
	}
	r.mu.RUnlock()

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
		}

	case protocol.MsgTypePass:
		err = r.game.Pass(client.ID)

	case protocol.MsgTypeChallenge:
		_, err = r.game.Challenge(client.ID)

	case protocol.MsgTypeJoinPrivateRoom:
		// Logic mostly handled in Manager.
		// If we did need it here, we'd process it.

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
				// Reply with Answer
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

	case protocol.MsgTypeStartGame:
		if r.isPrivate && client.ID != r.hostID {
			err = fmt.Errorf("only host can start the game")
		} else {
			err = r.game.Start()
		}

	case protocol.MsgTypeStartPrivateGame:
		if client.ID != r.hostID {
			err = fmt.Errorf("only host can start the game")
		} else {
			err = r.game.Start()
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
		// Valid move -> Broadcast new state
		r.broadcastState()

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

			// 2. Record in SQLite
			var playerIDs []string
			for _, p := range r.game.Participants {
				playerIDs = append(playerIDs, p.ID)
			}
			matchID := fmt.Sprintf("%s_%d", r.ID, time.Now().Unix())

			if err := db.RecordGameResult(matchID, playerIDs, r.game.WinnerID, 120, potAmount); err != nil {
				log.Printf("Failed to record game result: %v", err)
			}

			// 3. Broadcast Updated Stats
			// Note: broadcastStats requires mutex because it iterates clients.
			// Currently we HOLD mutex here (called from Run).
			// So internal helper should NOT lock.
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

func (r *Room) broadcastStats() {
	for client := range r.clients {
		stats, err := db.GetOrCreateUser(client.ID, "") // Name ignored on fetch
		if err == nil {
			msg := protocol.NewMessage("STATS_UPDATE", stats)
			bytes, _ := json.Marshal(msg)
			select {
			case client.Send <- bytes:
			default:
			}
		}
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

	for client := range r.clients {
		if client.IsSpectator {
			// Spectator View
			view := map[string]interface{}{
				"phase":          r.game.Phase,
				"myHand":         []interface{}{},
				"participants":   r.game.Participants,
				"pileCount":      r.game.PileCount,
				"activePlayerId": r.game.ActivePlayerID(),
				"declaredRank":   r.game.DeclaredRank,
				"isSpectator":    true,
			}
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

		view := map[string]interface{}{
			"phase":          r.game.Phase,
			"myHand":         p.Hand,
			"participants":   r.game.Participants,
			"pileCount":      r.game.PileCount,
			"activePlayerId": r.game.ActivePlayerID(),
			"declaredRank":   r.game.DeclaredRank,
		}

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
	roomInfo := map[string]interface{}{
		"roomCode":    r.code,
		"roomName":    r.name,
		"hostId":      r.hostID,
		"maxPlayers":  r.maxPlayers,
		"bootAmount":  r.bootAmount,
		"playerCount": len(r.clients),
	}

	// Participants List
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
	roomInfo["participants"] = participants
	roomInfo["isGameStarted"] = r.game.Phase != game.PhaseLobby

	msg := protocol.NewMessage(protocol.MsgTypeRoomUpdate, roomInfo)
	bytes, _ := json.Marshal(msg)

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
