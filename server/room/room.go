package room

import (
	"encoding/json"
	"log"
	
	"veil_server/game"
	"veil_server/protocol"
)

// Room represents a single game session
type Room struct {
	ID        string
	Clients   map[*Client]bool
	
	// Channels
	Broadcast chan []byte
	Register  chan *Client
	Unregister chan *Client
	
	// Game State
	Game *game.Game
	
	// Action Channel (Thread-safe game updates)
	Actions chan GameAction
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
	}
}

func (r *Room) Run() {
	for {
		select {
		case client := <-r.Register:
			r.Clients[client] = true
			log.Printf("Client joined Room %s", r.ID)
			
			// Auto-join game logic (simplified)
			if err := r.Game.AddPlayer(client.ID, "Player "+client.ID); err != nil {
				log.Printf("Error adding player: %v", err)
			}
			
			// Auto-start if full (Demo logic)
			if len(r.Game.Players) == game.MinPlayers && r.Game.Phase == game.PhaseLobby {
				r.Game.Start()
			}

			r.BroadcastState()
			
		case client := <-r.Unregister:
			if _, ok := r.Clients[client]; ok {
				delete(r.Clients, client)
				// Handle disconnect in game engine?
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
	}
	
	if err != nil {
		// Send error to specific client
		errBytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeError, protocol.ErrorMessage{
			Code:    "GAME_ERROR",
			Message: err.Error(),
		}))
		client.Send <- errBytes
	} else {
		// Valid move -> Broadcast new state
		r.BroadcastState()
	}
}

func (r *Room) BroadcastState() {
	// Full state sync for now (Inefficient but simple)
	// TODO: Create a clean serializable GameState struct in game/state.go
	// For now, assume r.Game is JSON serializable enough or manual map
	
	// We need to customize view per player (Hidden hands!)
	// But `Broadcast` channel sends SAME bytes to all.
	// FIX: Loop clients and send custom state.
	
	for client := range r.Clients {
		// Find player in game
		p := r.Game.PlayerMap[client.ID]
		if p == nil {
			continue
		}
		
		// Construct view
		view := map[string]interface{}{
			"phase": r.Game.Phase,
			"myHand": p.Hand, // Only visible to this client
			"participants": r.Game.Participants,
			"pileCount": r.Game.PileCount,
			"activePlayerId": r.Game.ActivePlayerID(),
			"declaredRank": r.Game.DeclaredRank,
		}
		
		msg := protocol.NewMessage(protocol.MsgTypeGameState, view)
		bytes, _ := json.Marshal(msg)
		client.Send <- bytes
	}
}
