package room

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"veil_server/db"
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
	b.room.broadcast <- bytes
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
	msg := protocol.NewMessage(protocol.MsgTypeVoiceState, b.room.voice)
	bytes, _ := json.Marshal(msg)

	for client := range b.room.clients {
		select {
		case client.Send <- bytes:
		default:
			log.Printf("Skip send voice to %s", client.ID)
		}
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

	// OPTIMIZATION: Build shared state once instead of per-client
	sharedState := map[string]interface{}{
		"phase":              b.room.game.Phase,
		"startTime":          b.room.game.StartTime,
		"participants":       b.room.game.Participants,
		"pileCount":          b.room.game.PileCount,
		"activePlayerId":     b.room.game.ActivePlayerID(),
		"declaredRank":       b.room.game.DeclaredRank,
		"lastEvent":          b.room.game.LastEvent,
		"lastEventId":        b.room.game.LastEventID,
		"lastEventActorId":   b.room.game.LastEventActorID,
		"lastEventCardCount": b.room.game.LastEventCardCount,
		"isBluffSuccessful":  b.room.game.IsBluffSuccessful,
		"gameLog":            b.room.game.GameLog,
		"createdAt":          b.room.CreationTime,
	}

	// Add lastMove if exists
	if b.room.game.LastMove != nil {
		sharedState["lastMove"] = map[string]interface{}{
			"playerId":     b.room.game.LastMove.PlayerID,
			"declaredRank": b.room.game.LastMove.DeclaredRank,
		}
	}

	for client := range b.room.clients {
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

		// Players get personalized view with their hand
		player := b.room.game.PlayerMap[client.ID]
		if player == nil {
			continue
		}

		view := make(map[string]interface{})
		for k, v := range sharedState {
			view[k] = v
		}
		view["myHand"] = player.Hand
		view["isSpectator"] = false

		msg := protocol.NewMessage(protocol.MsgTypeGameState, view)
		bytes, _ := json.Marshal(msg)
		select {
		case client.Send <- bytes:
		default:
			log.Printf("Skipped broadcast to %s", client.ID)
		}
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
	info := map[string]interface{}{
		"roomCode":     b.room.code,
		"roomName":     b.room.name,
		"hostId":       b.room.hostID,
		"maxPlayers":   b.room.maxPlayers,
		"bootAmount":   b.room.bootAmount,
		"participants": b.room.game.Participants,
		"phase":        b.room.game.Phase,
		"createdAt":    b.room.CreationTime,
	}

	msg := protocol.NewMessage(protocol.MsgTypeRoomUpdate, info)
	bytes, _ := json.Marshal(msg)

	for client := range b.room.clients {
		select {
		case client.Send <- bytes:
		default:
			log.Printf("Skipped room info to %s", client.ID)
		}
	}
}

// ForceBroadcastState allows external triggers (e.g. from Manager) to safely broadcast state
func (b *Broadcaster) ForceBroadcastState() {
	b.BroadcastState()
}
