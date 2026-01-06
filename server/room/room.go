package room

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"veil_server/db"
	"veil_server/game"
	"veil_server/protocol"

	"github.com/pion/webrtc/v3"
)

// Room represents a single game session
type Room struct {
	ID      string
	Clients map[*Client]bool

	// Channels
	Broadcast  chan []byte
	Register   chan *Client
	Unregister chan *Client

	// Game State
	Game *game.Game

	// Action Channel (Thread-safe game updates)
	Actions chan GameAction

	// Private Room Fields
	Name       string
	Code       string
	Password   string
	IsPrivate  bool
	HostID     string
	MaxPlayers int
	BootAmount float64
	Voice      *game.VoiceState
	WebRTC     *game.WebRTCManager
}

type GameAction struct {
	Client  *Client
	Message protocol.BaseMessage
}

func NewRoom(id string) *Room {
	return &Room{
		ID:         id,
		Broadcast:  make(chan []byte),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
		Clients:    make(map[*Client]bool),
		Game:       game.NewGame(),
		Actions:    make(chan GameAction),
		MaxPlayers: game.MaxPlayers, // Default
		Voice:      game.NewVoiceState(),
		WebRTC:     game.NewWebRTCManager(),
	}
}

func NewPrivateRoom(id, name, code, password, hostID string, maxPlayers int, bootAmount float64) *Room {
	r := NewRoom(id)
	r.Name = name
	r.Code = code
	r.Password = password
	r.IsPrivate = true
	r.HostID = hostID
	r.MaxPlayers = maxPlayers
	r.BootAmount = bootAmount
	r.Voice = game.NewVoiceState()
	r.WebRTC = game.NewWebRTCManager()
	return r
}

func (r *Room) Run() {
	ticker := time.NewTicker(200 * time.Millisecond) // Faster ticker for voice updates?
	// Or keep 1s? Voice needs roughly 1s updates for timer.
	// 200ms is safer for UI responsiveness if we want to catch state changes quickly.
	defer func() {
		ticker.Stop()
		close(r.Register)
		close(r.Unregister)
		close(r.Actions)
	}()

	for {
		select {
		case client := <-r.Register:
			r.Clients[client] = true
			log.Printf("Client joined Room %s (Spectator: %v)", r.ID, client.IsSpectator)

			if !client.IsSpectator {
				// Auto-join game logic (simplified)
				if err := r.Game.AddPlayer(client.ID, "Player "+client.ID); err != nil {
					log.Printf("Error adding player: %v", err)
				}

				// No auto-start at 2 players anymore, let them choose.
				// But auto-start if lobby reaches absolute MaxPlayers (ONLY FOR PUBLIC).
				if !r.IsPrivate && len(r.Game.Players) == game.MaxPlayers && r.Game.Phase == game.PhaseLobby {
					r.Game.Start()
				}
			}

			if r.IsPrivate {
				r.BroadcastRoomInfo() // Update lobby UI
			} else {
				r.BroadcastState()
			}

		case client := <-r.Unregister:
			if _, ok := r.Clients[client]; ok {
				delete(r.Clients, client)
				// Also remove from game engine to allow reconnects/slots
				r.Game.RemovePlayer(client.ID)
				// Also remove from voice queue/speaker
				r.Voice.ReleaseMic(client.ID)
				log.Printf("Client left Room %s", r.ID)

				// If Host leaves, assign new host (if anyone left)
				if r.IsPrivate && client.ID == r.HostID {
					if len(r.Game.Players) > 0 {
						// Assign generic first player as host
						for _, p := range r.Game.Players {
							r.HostID = p.ID
							break
						}
					}
				}

				if r.IsPrivate {
					r.BroadcastRoomInfo()
				} else {
					r.BroadcastState()
				}
			}

		case action := <-r.Actions:
			r.processAction(action)

		case message := <-r.Broadcast:
			for client := range r.Clients {
				select {
				case client.Send <- message:
				default:
					close(client.Send)
					delete(r.Clients, client)
				}
			}

		case <-ticker.C:
			// Game Tick (e.g. turn timers)
			if r.Game.Phase != game.PhaseLobby && r.Game.Phase != game.PhaseFinished {
				// r.Game.Tick() // If we had game timers
			}

			// Voice Tick
			if r.Voice.Tick() {
				// Update WebRTC component with new speaker (or empty)
				r.WebRTC.SetSpeaker(r.Voice.CurrentSpeakerID)

				r.BroadcastVoiceState()
			}
		}
	}
}

func (r *Room) processAction(action GameAction) {
	client := action.Client
	msg := action.Message

	var err error

	switch msg.Type {
	case protocol.MsgTypePlayCards:
		var payload protocol.PlayCardsMessage
		if json.Unmarshal(msg.Data, &payload) == nil {
			err = r.Game.PlayCards(client.ID, payload.CardIDs, game.Rank(payload.DeclaredRank))
		}

	case protocol.MsgTypePass:
		err = r.Game.Pass(client.ID)

	case protocol.MsgTypeChallenge:
		_, err = r.Game.Challenge(client.ID)

	case protocol.MsgTypeJoinPrivateRoom:
		var payload protocol.JoinPrivateRoomMessage
		if json.Unmarshal(msg.Data, &payload) == nil {
			// Logic handled in Manager usually, but if we need room-specific logic:
			// Actually manager.go handles routing to the room.
			// The room itself receives the client via Register channel.
			// We need to know if they are a spectator.
			// Currently Register channel only passes *Client.
			// We might need to update Client state BEFORE registering or handle it here?
			// The Client struct now has IsSpectator.
		}

	case protocol.MsgTypeVoiceHandRaise:
		// Toggle: If speaking/queued, remove. If not, add.
		// Actually spec says "Raise Hand" -> "Queue".
		// Implementing toggle is nicer UX usually, but let's stick to "Raise" adds to queue.
		// Wait, user doc says "Tap Raise Hand". If they tap again?
		// Let's make it a request to join queue.
		// If already in queue, maybe remove? (Cancel request).
		// Let's implement smart toggle: Request if not in, Release if in.

		isQueued := false
		for _, id := range r.Voice.Queue {
			if id == client.ID {
				isQueued = true
				break
			}
		}

		if r.Voice.CurrentSpeakerID == client.ID || isQueued {
			r.Voice.ReleaseMic(client.ID)
		} else {
			r.Voice.RequestMic(client.ID)
		}

		r.BroadcastVoiceState()

	case protocol.MsgTypeVoiceSDP:
		var offer webrtc.SessionDescription
		if json.Unmarshal(msg.Data, &offer) == nil {
			answer, err := r.WebRTC.HandleOffer(client.ID, offer)
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
			if err := r.WebRTC.HandleICE(client.ID, candidate); err != nil {
				log.Printf("WebRTC ICE Error for %s: %v", client.ID, err)
			}
		}

	case protocol.MsgTypeStartGame:
		// Public room generic start or Private room host start
		if r.IsPrivate && client.ID != r.HostID {
			err = fmt.Errorf("only host can start the game")
		} else {
			err = r.Game.Start()
		}

	case protocol.MsgTypeStartPrivateGame:
		if client.ID != r.HostID {
			err = fmt.Errorf("only host can start the game")
		} else {
			err = r.Game.Start()
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
		r.BroadcastState()

		// NEW: Check if game just ended
		// We'll trust the game Phase to tell us.
		// NOTE: This assumes Game.Phase switches to PhaseGameOver after a winning move.
		if r.Game.Phase == game.PhaseFinished {
			log.Printf("Game Over in Room %s! Winner: %s", r.ID, r.Game.WinnerID)

			// 1. Record in SQLite
			var playerIDs []string
			for _, p := range r.Game.Participants {
				playerIDs = append(playerIDs, p.ID)
			}
			matchID := fmt.Sprintf("%s_%d", r.ID, time.Now().Unix())

			// Simple duration (mocked as 60s for now, or track start time in Room later)
			if err := db.RecordGameResult(matchID, playerIDs, r.Game.WinnerID, 120); err != nil {
				log.Printf("Failed to record game result: %v", err)
			}

			// 2. Broadcast Updated Stats to each client
			go r.BroadcastStats()
		}
	}
}

func (r *Room) BroadcastStats() {
	for client := range r.Clients {
		stats, err := db.GetOrCreateUser(client.ID, "") // Name ignored on fetch
		if err == nil {
			msg := protocol.NewMessage("STATS_UPDATE", stats)
			bytes, _ := json.Marshal(msg)
			client.Send <- bytes
		}
	}
}

func (r *Room) BroadcastVoiceState() {
	msg := protocol.NewMessage(protocol.MsgTypeVoiceState, r.Voice)
	bytes, _ := json.Marshal(msg)

	for client := range r.Clients {
		select {
		case client.Send <- bytes:
		default:
			log.Printf("Skip send voice to %s", client.ID)
		}
	}
}

func (r *Room) BroadcastState() {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("Recovered from panic in BroadcastState: %v", err)
		}
	}()

	for client := range r.Clients {
		if client.IsSpectator {
			// Spectator View
			view := map[string]interface{}{
				"phase":          r.Game.Phase,
				"myHand":         []interface{}{}, // Empty hand for spectators
				"participants":   r.Game.Participants,
				"pileCount":      r.Game.PileCount,
				"activePlayerId": r.Game.ActivePlayerID(),
				"declaredRank":   r.Game.DeclaredRank,
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

		p := r.Game.PlayerMap[client.ID]
		if p == nil {
			continue
		}

		view := map[string]interface{}{
			"phase":          r.Game.Phase,
			"myHand":         p.Hand,
			"participants":   r.Game.Participants,
			"pileCount":      r.Game.PileCount,
			"activePlayerId": r.Game.ActivePlayerID(),
			"declaredRank":   r.Game.DeclaredRank,
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

func (r *Room) BroadcastRoomInfo() {
	roomInfo := map[string]interface{}{
		"roomCode":    r.Code,
		"roomName":    r.Name,
		"hostId":      r.HostID,
		"maxPlayers":  r.MaxPlayers,
		"bootAmount":  r.BootAmount,
		"playerCount": len(r.Clients),
	}

	// Participants List
	var participants []map[string]interface{}
	for client := range r.Clients {
		p := map[string]interface{}{
			"id":       client.ID,
			"name":     "Player " + client.ID, // Or fetch real name
			"isActive": true,
		}
		if r.Game.PlayerMap[client.ID] != nil {
			p["name"] = r.Game.PlayerMap[client.ID].Name
		}
		participants = append(participants, p)
	}
	roomInfo["participants"] = participants
	roomInfo["isGameStarted"] = r.Game.Phase != game.PhaseLobby

	msg := protocol.NewMessage(protocol.MsgTypeRoomUpdate, roomInfo)
	bytes, _ := json.Marshal(msg)

	for client := range r.Clients {
		select {
		case client.Send <- bytes:
		default:
		}
	}
}
