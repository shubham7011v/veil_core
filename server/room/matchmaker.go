package room

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"veil_server/config"
	"veil_server/db"
)

// Matchmaker handles lobby management and matchmaking operations
// Extracted from Manager to improve modularity and single-responsibility
type Matchmaker struct {
	manager *Manager
}

// NewMatchmaker creates a new matchmaking handler
func NewMatchmaker(m *Manager) *Matchmaker {
	return &Matchmaker{manager: m}
}

// Constants for matchmaking
const (
	LobbyTimeout  = 10 * time.Second
	TargetPlayers = 5
	RoomCodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excludes I, O, 0, 1
)

// CheckLobbyTimeout checks if the active lobby has waited too long
// and needs to be filled with bots to start the game.
func (mm *Matchmaker) CheckLobbyTimeout() {
	mm.manager.mu.Lock()
	defer mm.manager.mu.Unlock()

	lobby := mm.manager.ActiveLobby
	if lobby == nil {
		return
	}

	// Check if lobby is still valid/open (sanity check)
	if lobby.GetGamePhase() != "Lobby" || mm.manager.ActiveLobbyCount >= TargetPlayers {
		mm.manager.ActiveLobby = nil
		mm.manager.ActiveLobbyCount = 0
		return
	}

	if time.Since(mm.manager.ActiveLobbyStartTime) > LobbyTimeout {
		// Timeout Reached! Fill with Bots.
		if !config.GetFeatureFlags().EnableBotPlayers {
			return // Leave open if bots disabled
		}

		botsNeeded := TargetPlayers - mm.manager.ActiveLobbyCount

		if botsNeeded <= 0 {
			mm.manager.ActiveLobby = nil
			mm.manager.ActiveLobbyCount = 0
			return
		}

		log.Printf("Lobby Timeout: Spawning %d bots for Room %s", botsNeeded, lobby.ID)

		// Spawn Bots
		for i := 0; i < botsNeeded; i++ {
			bot := NewBot(mm.manager)
			bot.Client.CurrentRoom = lobby
			lobby.Join(bot.Client)
		}

		// Seal the lobby so no new humans join this bot-filled game
		mm.manager.ActiveLobby = nil
		mm.manager.ActiveLobbyCount = 0
	}
}

// AttemptJoinActiveLobby handles robust locking to put a client in the current open room
func (mm *Matchmaker) AttemptJoinActiveLobby(c *Client) {
	// 1. Pre-Check: Validate coins BEFORE locking or assigning slot
	// This prevents "Ghost Slots" where a user takes a slot but is later rejected by the room.
	stats, err := db.GetOrCreateUser(c.ID, "")
	if err != nil || stats.Coins < 100 {
		mm.manager.sendError(c, "INSUFFICIENT_FUNDS", "You need 100 coins to play online")
		return
	}

	mm.manager.mu.Lock()
	defer mm.manager.mu.Unlock()

	// Double-Check: Ensure client didn't join a room while waiting for lock
	if c.CurrentRoom != nil {
		return
	}

	// Validate if we have a valid ActiveLobby
	if mm.manager.ActiveLobby != nil {
		if mm.manager.ActiveLobbyCount >= TargetPlayers {
			mm.manager.ActiveLobby = nil
			mm.manager.ActiveLobbyCount = 0
		} else if mm.manager.ActiveLobby.GetGamePhase() != "Lobby" {
			mm.manager.ActiveLobby = nil
			mm.manager.ActiveLobbyCount = 0
		}
	}

	// Create if missing
	if mm.manager.ActiveLobby == nil {
		roomID := fmt.Sprintf("match_%d", time.Now().UnixNano())
		room := NewRoom(roomID)
		mm.manager.Rooms[roomID] = room

		go room.Run() // Start the room loop

		mm.manager.ActiveLobby = room
		mm.manager.ActiveLobbyCount = 0
		mm.manager.ActiveLobbyStartTime = time.Now()
		room.CreationTime = mm.manager.ActiveLobbyStartTime.Unix()
		log.Printf("Created New Active Lobby: %s", roomID)
	}

	// Join - Increment sync counter immediately to reserve the slot
	mm.manager.ActiveLobbyCount++

	c.CurrentRoom = mm.manager.ActiveLobby
	mm.manager.ActiveLobby.Join(c)

	// If we just hit max, clear ActiveLobby
	if mm.manager.ActiveLobbyCount >= TargetPlayers {
		mm.manager.ActiveLobby = nil
		mm.manager.ActiveLobbyCount = 0
	}
}

// GenerateRoomCode creates a unique room code for private rooms
func (mm *Matchmaker) GenerateRoomCode() string {
	b := make([]byte, 6)
	for i := range b {
		b[i] = RoomCodeChars[rand.Intn(len(RoomCodeChars))]
	}
	return string(b)
}

// CleanupEmptyRooms removes rooms that have no active clients
func (mm *Matchmaker) CleanupEmptyRooms() {
	mm.manager.mu.Lock()
	defer mm.manager.mu.Unlock()

	for id, room := range mm.manager.Rooms {
		// Never cleanup the ActiveLobby while it is active
		if room == mm.manager.ActiveLobby {
			continue
		}

		// Cleanup if empty
		if room.GetClientCount() == 0 {
			log.Printf("Cleaning up empty room: %s", id)
			room.Stop()
			delete(mm.manager.Rooms, id)
		}
	}
}
