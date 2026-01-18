package room

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"time"

	"veil_server/config"
	"veil_server/game"
	"veil_server/internal/domain/user"
	"veil_server/protocol"
)

// Matchmaker handles lobby management and matchmaking operations
// Extracted from Manager to improve modularity and single-responsibility
type Matchmaker struct {
	manager  *Manager
	userRepo user.Repository
}

// NewMatchmaker creates a new matchmaking handler
func NewMatchmaker(m *Manager, repo user.Repository) *Matchmaker {
	return &Matchmaker{
		manager:  m,
		userRepo: repo,
	}
}

// Matchmaking Settings
var (
	LobbyTimeout  = 50 * time.Second
	TargetPlayers = 5
)

const RoomCodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excludes I, O, 0, 1

func init() {
	// Allow overriding via environment variables for testing
	if val, exists := os.LookupEnv("LOBBY_TIMEOUT_S"); exists {
		if s, err := time.ParseDuration(val + "s"); err == nil {
			LobbyTimeout = s
		}
	}
	if val, exists := os.LookupEnv("MAX_PLAYERS"); exists {
		var i int
		if _, err := fmt.Sscanf(val, "%d", &i); err == nil {
			TargetPlayers = i
		}
	}
}

// CheckLobbyTimeout checks if the active lobby has waited too long
// and needs to be filled with bots to start the game.
func (mm *Matchmaker) CheckLobbyTimeout() {
	mm.manager.mu.Lock()
	defer mm.manager.mu.Unlock()

	lobby := mm.manager.ActiveLobby
	if lobby == nil {
		return
	}

	// Dynamic timeout for testing/config
	currentTimeout := LobbyTimeout
	if val, exists := os.LookupEnv("LOBBY_TIMEOUT_S"); exists {
		if s, err := time.ParseDuration(val + "s"); err == nil {
			currentTimeout = s
		}
	}

	// Check if lobby is full (no need for bots)
	if mm.manager.ActiveLobbyCount >= TargetPlayers {
		mm.manager.ActiveLobby = nil
		mm.manager.ActiveLobbyCount = 0
		return
	}

	if time.Since(mm.manager.ActiveLobbyStartTime) > currentTimeout {
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

		// Seal the lobby
		mm.manager.ActiveLobby = nil
		mm.manager.ActiveLobbyCount = 0
	} else {
		// Log how much time is left
		timeLeft := currentTimeout - time.Since(mm.manager.ActiveLobbyStartTime)
		log.Printf("Lobby %s waiting for timeout (%v remaining, count: %d/%d)",
			lobby.ID, timeLeft, mm.manager.ActiveLobbyCount, TargetPlayers)
	}
}

// AttemptJoinActiveLobby handles robust locking to put a client in the current open room
func (mm *Matchmaker) AttemptJoinActiveLobby(c *Client) {
	// 1. Pre-Check: Validate coins BEFORE locking or assigning slot
	// This prevents "Ghost Slots" where a user takes a slot but is later rejected by the room.
	// 1. Pre-Check: Validate coins BEFORE locking or assigning slot
	// This prevents "Ghost Slots" where a user takes a slot but is later rejected by the room.
	var u *user.User
	var err error

	// Retry loop for SQLite busy/locked errors
	for i := 0; i < 5; i++ {
		u, err = mm.userRepo.GetOrCreate(c.ID, "")
		if err == nil {
			break
		}
		// If it's a transient lock error, wait and retry
		errMsg := err.Error()
		if i < 4 && (strings.Contains(errMsg, "locked") || strings.Contains(errMsg, "busy")) {
			time.Sleep(time.Duration(100+rand.Intn(200)) * time.Millisecond)
			continue
		}
		break
	}

	if err != nil || u == nil || u.Coins < 100 {
		coins := -1
		if u != nil {
			coins = u.Coins
		}
		log.Printf("DEBUG: Player %s failed coin check after retries. err: %v, coins: %d", c.ID, err, coins)
		mm.manager.sendError(c, protocol.ErrCodeLowBalance, "You need 100 coins to play online")
		return
	}
	log.Printf("DEBUG: Player %s passed coin check (coins: %d)", c.ID, u.Coins)

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
		} else if mm.manager.ActiveLobby.GetGamePhase() != string(game.PhaseLobby) {
			mm.manager.ActiveLobby = nil
			mm.manager.ActiveLobbyCount = 0
		}
	}

	// Create if missing
	if mm.manager.ActiveLobby == nil {
		roomID := fmt.Sprintf("match_%d", time.Now().UnixNano())
		room := NewRoom(roomID, mm.manager)
		room.SetMaxPlayers(TargetPlayers) // Override default (10) with matchmaking target (5)
		room.SessionExpiry = mm.manager.ExpiredSessions

		// Set cleanup callback
		room.OnStop = func() {
			mm.manager.mu.Lock()
			delete(mm.manager.Rooms, roomID)
			mm.manager.mu.Unlock()
			log.Printf("Manager: Cleaned up room %s after stop", roomID)
		}

		mm.manager.Rooms[roomID] = room

		go room.Run() // Start the room loop

		mm.manager.ActiveLobby = room
		mm.manager.ActiveLobbyCount = 0
		mm.manager.ActiveLobbyStartTime = time.Now()
		room.session.CreatedAt = mm.manager.ActiveLobbyStartTime.Unix()
		log.Printf("Created New Active Lobby: %s (max: %d)", roomID, TargetPlayers)
	}

	// Join - Increment sync counter immediately to reserve the slot
	mm.manager.ActiveLobbyCount++
	log.Printf("DEBUG: Matchmaking Reservation SUCCESS for %s. New Count: %d", c.ID, mm.manager.ActiveLobbyCount)
	log.Printf("Matchmaking: Client %s reserved slot. Lobby count: %d/%d",
		c.ID, mm.manager.ActiveLobbyCount, TargetPlayers)

	c.CurrentRoom = mm.manager.ActiveLobby
	mm.manager.ActiveLobby.Join(c)

	// ✅ Index for O(1) Session Restoration
	mm.manager.PlayerRooms[c.ID] = mm.manager.ActiveLobby

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
