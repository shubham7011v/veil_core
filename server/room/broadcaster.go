package room

import (
	"encoding/json"
	"log"
	"sync"
	"time"
	"veil_server/game"
	"veil_server/protocol"
)

// Broadcaster handles all broadcast operations for a room
// This separates the concern of message distribution from core room logic
type Broadcaster struct {
	room *Room
	mu   *sync.RWMutex // Reference to room's mutex for thread safety
}

// NewBroadcaster creates a new broadcaster for the given room
func NewBroadcaster(r *Room) *Broadcaster {
	return &Broadcaster{
		room: r,
		mu:   &r.mu,
	}
}

// sendToClient handles backpressure by prioritizing critical messages
// sendToClient handles backpressure and is safe against closed channels
func (b *Broadcaster) sendToClient(c *Client, bytes []byte, critical bool) {
	defer func() {
		if r := recover(); r != nil {
			// This happens if c.Send was closed concurrently
			// We skip this client; they are likely already disconnected or disconnecting
		}
	}()

	// log.Printf("Sending %d bytes to %s (Critical: %v)", len(bytes), c.ID, critical)
	select {
	case c.Send <- bytes:
		// Success
	default:
		// Buffer full!
		if critical {
			// For critical messages (Game State, Room Info), wait up to 100ms
			select {
			case c.Send <- bytes:
			case <-time.After(100 * time.Millisecond):
				log.Printf("BACKPRESSURE: Dropped CRITICAL update to %s (buffer full)", c.ID)
			}
		} else {
			// For non-critical messages (Voice, Stats), skip immediately
		}
	}
}

// BroadcastActionLocked sends a lightweight action event to all clients
// Caller must hold room.mu
func (b *Broadcaster) BroadcastActionLocked(action string, data map[string]interface{}) {
	// Generate monotonic sequence number (thread-safe due to room.mu lock)
	b.room.eventSequence++

	msg := protocol.NewMessage(protocol.MsgTypeGameAction, map[string]interface{}{
		"action":    action,
		"data":      data,
		"timestamp": time.Now().Unix(),
		"sequence":  b.room.eventSequence,
	})
	bytes, _ := json.Marshal(msg)

	for client := range b.room.clients {
		b.sendToClient(client, bytes, true) // Actions are usually critical
	}
}

// BroadcastStats sends updated player statistics to all clients
func (b *Broadcaster) BroadcastStats() {
	b.mu.RLock()
	defer b.mu.RUnlock()
	b.BroadcastStatsLocked()
}

// BroadcastStatsLocked sends updated player statistics to all clients
// Caller must hold room.mu
func (b *Broadcaster) BroadcastStatsLocked() {
	var clients []*Client
	for c := range b.room.clients {
		clients = append(clients, c)
	}

	// Perform DB lookups and sends in goroutine to avoid blocking
	// Note: We copy clients slice so we don't need lock during iteration
	go func(clients []*Client) {
		for _, client := range clients {
			u, err := b.room.manager.UserRepo.GetOrCreate(client.ID, "")
			if err == nil {
				// Map to legacy stats format for protocol compatibility
				stats := map[string]interface{}{
					"userId":      u.ID,
					"name":        u.Name,
					"gamesPlayed": u.GamesPlayed,
					"wins":        u.Wins,
					"losses":      u.Losses,
					"rank":        u.Rank,
					"coins":       u.Coins,
					"avatarUrl":   u.AvatarURL,
				}
				msg := protocol.NewMessage("STATS_UPDATE", stats)
				bytes, _ := json.Marshal(msg)
				b.sendToClient(client, bytes, false) // Stats are non-critical
			}
		}
	}(clients)
}

// BroadcastVoiceState sends current voice chat state to all clients
func (b *Broadcaster) BroadcastVoiceState() {
	b.mu.RLock()
	defer b.mu.RUnlock()
	b.BroadcastVoiceStateLocked()
}

// BroadcastVoiceStateLocked sends current voice chat state to all clients
// Caller must hold room.mu
func (b *Broadcaster) BroadcastVoiceStateLocked() {
	msg := protocol.NewMessage(protocol.MsgTypeVoiceState, b.room.session.Voice)
	bytes, _ := json.Marshal(msg)

	for client := range b.room.clients {
		b.sendToClient(client, bytes, false) // Voice is non-critical
	}
}

// BroadcastState sends the complete game state to all clients
func (b *Broadcaster) BroadcastState() {
	b.mu.RLock()
	defer b.mu.RUnlock()
	b.BroadcastStateLocked()
}

// BroadcastStateLocked sends the complete game state to all clients
// Caller must hold room.mu
func (b *Broadcaster) BroadcastStateLocked() {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("Recovered from panic in BroadcastState: %v", err)
		}
	}()

	s := b.room.session
	g := s.Game

	// OPTIMIZATION: Build shared state once instead of per-client
	sharedBaseState := map[string]interface{}{
		"phase":              g.Phase,
		"startTime":          g.StartTime,
		"turnStartTime":      g.TurnStartTime,
		"pileCount":          g.PileCount,
		"activePlayerId":     g.ActivePlayerID(),
		"declaredRank":       g.DeclaredRank,
		"lastEvent":          g.LastEvent,
		"lastEventId":        g.LastEventID,
		"lastEventActorId":   g.LastEventActorID,
		"lastEventCardCount": g.LastEventCardCount,
		"gameLog":            g.GameLog,
		"createdAt":          s.CreatedAt,
		"winnerId":           g.WinnerID,
	}

	// Only reveal bluff result during Revealing or Finished phases
	if g.Phase == game.PhaseRevealing || g.Phase == game.PhaseFinished {
		sharedBaseState["isBluffSuccessful"] = g.IsBluffSuccessful
	}

	// Add lastMove if exists
	if g.LastMove != nil {
		moveData := map[string]interface{}{
			"playerId":     g.LastMove.PlayerID,
			"declaredRank": g.LastMove.DeclaredRank,
		}
		// REVEAL: Only show actual cards during Revealing or Finished phases
		if g.Phase == game.PhaseRevealing || g.Phase == game.PhaseFinished {
			moveData["actualCards"] = g.LastMove.ActualCards
		}
		sharedBaseState["lastMove"] = moveData
	}

	for client := range b.room.clients {
		// Personalized participants for this client
		participants := g.GetParticipantsView(client.ID)

		if client.IsSpectator {
			// Spectators get shared state + empty hand
			view := make(map[string]interface{})
			for k, v := range sharedBaseState {
				view[k] = v
			}
			view["participants"] = participants
			view["myHand"] = []interface{}{}
			view["isSpectator"] = true

			msg := protocol.NewMessage(protocol.MsgTypeGameState, view)
			bytes, _ := json.Marshal(msg)
			b.sendToClient(client, bytes, true) // Game State is critical
			continue
		}

		// Players get personalized view with their hand
		player := g.PlayerMap[client.ID]
		if player == nil {
			continue
		}

		view := make(map[string]interface{})
		for k, v := range sharedBaseState {
			view[k] = v
		}
		view["participants"] = participants
		view["myHand"] = player.Hand
		view["isSpectator"] = false

		msg := protocol.NewMessage(protocol.MsgTypeGameState, view)
		bytes, _ := json.Marshal(msg)
		b.sendToClient(client, bytes, true) // Game State is critical
	}
}

// BroadcastRoomInfo sends private room information to all clients
func (b *Broadcaster) BroadcastRoomInfo() {
	b.mu.RLock()
	defer b.mu.RUnlock()
	b.BroadcastRoomInfoLocked()
}

// BroadcastRoomInfoLocked sends private room information to all clients
// Caller must hold room.mu
func (b *Broadcaster) BroadcastRoomInfoLocked() {
	s := b.room.session
	for client := range b.room.clients {
		// Personalized participants for this client
		participants := s.Game.GetParticipantsView(client.ID)

		info := map[string]interface{}{
			"roomCode":     s.Settings.Code,
			"roomName":     s.Settings.Name,
			"hostId":       s.Settings.HostID,
			"maxPlayers":   s.Settings.MaxPlayers,
			"bootAmount":   s.Settings.BootAmount,
			"participants": participants,
			"phase":        s.Game.Phase,
			"createdAt":    s.CreatedAt,
		}

		msg := protocol.NewMessage(protocol.MsgTypeRoomUpdate, info)
		bytes, _ := json.Marshal(msg)
		b.sendToClient(client, bytes, true) // Room info is critical
	}
}

// ForceBroadcastState allows external triggers (e.g. from Manager) to safely broadcast state
func (b *Broadcaster) ForceBroadcastState() {
	b.BroadcastState()
}
