package room

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"sync"
	"time"
	"veil_server/config"
	"veil_server/db"
	"veil_server/protocol"

	"firebase.google.com/go/v4/auth"
)

const (
	charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excludes I, O, 0, 1
)

// ActiveRoomInfo for admin dashboard
type ActiveRoomInfo struct {
	ID          string   `json:"id"`
	PlayerCount int      `json:"playerCount"`
	Phase       string   `json:"phase"`
	PlayerIDs   []string `json:"playerIds"`
}

// Manager keeps track of all clients and rooms
type Manager struct {
	mu         sync.RWMutex
	Clients    map[*Client]bool
	Register   chan *Client
	Unregister chan *Client

	Rooms map[string]*Room
	Queue *MatchmakingQueue

	AuthClient *auth.Client
}

func NewManager(authClient *auth.Client) *Manager {
	m := &Manager{
		Clients:    make(map[*Client]bool),
		Register:   make(chan *Client, 256), // Buffered to prevent blocking
		Unregister: make(chan *Client, 256),
		Rooms:      make(map[string]*Room),
		AuthClient: authClient,
	}
	m.Queue = NewMatchmakingQueue()
	return m
}

func (m *Manager) Run() {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Manager Recovered from panic: %v", r)
			go m.Run() // Restart
		}
	}()

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case client := <-m.Register:
			m.Clients[client] = true
			log.Println("New Connection Registered")

		case client := <-m.Unregister:
			if _, ok := m.Clients[client]; ok {
				delete(m.Clients, client)
				m.Queue.Remove(client) // Remove from queue if waiting
				if client.CurrentRoom != nil {
					client.CurrentRoom.Leave(client)
				}
				if !client.IsBot {
					close(client.Send)
				}
				log.Println("Connection Unregistered")
			}

		case <-ticker.C:
			// Process Matchmaking Queue safely in this thread
			// Use a loop to clear the entire queue in one go if multiple people are waiting
			for {
				clients, _ := m.Queue.Tick()
				if clients == nil {
					break
				}

				// Bot Logic Refinement:
				// 1. If only 1 human (timeout), fill to 5 players (4 Bots) for a full game.
				// 2. If 2+ humans, start immediately with NO Bots (respecting user preference).

				targetCount := len(clients)
				if len(clients) == 1 {
					targetCount = 5
				}

				log.Printf("Process Queue: %d clients. Target: %d. Enabled: %v", len(clients), targetCount, config.GetFeatureFlags().EnableBotPlayers)

				if len(clients) < targetCount && config.GetFeatureFlags().EnableBotPlayers {
					botsNeeded := targetCount - len(clients)
					for i := 0; i < botsNeeded; i++ {
						bot := NewBot(m)
						clients = append(clients, bot.Client)
					}
					log.Printf("Spawning %d Bots. Final Client Count: %d", botsNeeded, len(clients))
				}

				m.createMatchRoom(clients)
			}
		}
	}
}

func (m *Manager) createMatchRoom(clients []*Client) {
	roomID := fmt.Sprintf("match_%d", time.Now().UnixNano())
	room := NewRoom(roomID)
	room.maxPlayers = len(clients) // Crucial for auto-start with bots/matchmaking
	m.Rooms[roomID] = room
	go room.Run()

	log.Printf("Starting Match Room %s with %d players (max: %d)", roomID, len(clients), room.maxPlayers)

	for _, c := range clients {
		c.CurrentRoom = room
		room.Join(c)
	}

	// The room's register loop will auto-start the game when len(r.game.Players) == r.maxPlayers
}

// HandleMessage routes incoming messages from clients
// TODO: Refactor this large switch statement into a map-based handler system
// or separate message handlers for better modularity and testability.
func (m *Manager) HandleMessage(c *Client, message []byte) {
	// 1. Parse ONLY the type first
	var baseMsg protocol.BaseMessage
	if err := json.Unmarshal(message, &baseMsg); err != nil {
		// TODO: Implement more robust error reporting to the client for invalid messages
		log.Printf("Invalid JSON: %v", err)
		return
	}

	// log.Printf("Msg Type: %s from Client %v", baseMsg.Type, c.ID)

	// 2. Global Handlers (Auth, Join Room)
	switch baseMsg.Type {
	case protocol.MsgTypeAuth:
		var authData protocol.AuthMessage
		if err := json.Unmarshal(baseMsg.Data, &authData); err != nil {
			log.Printf("Auth unmarshal error: %v", err)
			return
		}

		tokenString := authData.Token
		userName := authData.Name

		// Verify Token if possible
		userID := tokenString
		firebaseName := userName
		firebaseAvatar := authData.AvatarURL

		if m.AuthClient != nil && !strings.HasPrefix(tokenString, "mock_") {
			token, err := m.AuthClient.VerifyIDToken(context.Background(), tokenString)
			if err == nil {
				userID = token.UID
				log.Printf("Verified user: %s", userID)

				// Optionally take name/avatar from token if client didn't send
				if firebaseName == "" && token.Claims["name"] != nil {
					firebaseName = token.Claims["name"].(string)
				}
				if firebaseAvatar == "" && token.Claims["picture"] != nil {
					firebaseAvatar = token.Claims["picture"].(string)
				}
			} else {
				// Use a truncated version for logging if it's a huge token
				displayID := tokenString
				if len(displayID) > 20 {
					displayID = displayID[:20] + "..."
				}
				log.Printf("Token verification failed (falling back to %s): %v", displayID, err)
			}
		}

		if firebaseName == "" {
			nameID := userID
			if len(nameID) > 4 {
				nameID = nameID[:4]
			}
			firebaseName = "Player " + nameID
		}

		c.ID = userID
		c.Name = firebaseName
		c.AvatarURL = firebaseAvatar

		// Get Data from SQLite (Initial sync)
		stats, err := db.GetOrCreateUser(c.ID, firebaseName)
		if err == nil {
			// Update avatar if provided and different
			if firebaseAvatar != "" {
				db.UpdateUserAvatar(c.ID, firebaseAvatar)
				stats.AvatarURL = firebaseAvatar // Assuming field exists in db.UserStats
			}
		} else {
			log.Printf("DB Error: %v", err)
			stats = &db.UserStats{UserID: c.ID, Name: "Unknown", Rank: "Novice", Coins: 1000}
		}

		m.sendAuthOk(c, stats)
		return // Handled

	case protocol.MsgTypeUpdateName:
		var payload protocol.UpdateNameMessage
		if err := json.Unmarshal(baseMsg.Data, &payload); err != nil {
			log.Printf("Update Name parse error: %v", err)
			return
		}

		// Update in DB
		if err := db.UpdateUserName(c.ID, payload.Name); err != nil {
			log.Printf("DB Update error: %v", err)
			return
		}

		// Fetch updated stats to confirm to client
		stats, err := db.GetOrCreateUser(c.ID, payload.Name)
		if err == nil {
			// This forces a refresh on the client side
			m.sendAuthOk(c, stats)
		}
		return

	case protocol.MsgTypeRefillCoins:
		// Check current balance
		stats, err := db.GetOrCreateUser(c.ID, "")
		if err != nil {
			log.Printf("Refill error fetch: %v", err)
			return
		}

		if stats.Coins < 100 {
			// Refill to 1000
			topUp := 1000 - stats.Coins
			if err := db.UpdateUserCoins(c.ID, topUp); err == nil {
				stats.Coins = 1000
				m.sendAuthOk(c, stats)
			}
		} else {
			m.sendError(c, "REFILL_DENIED", "You have enough coins!")
		}
		return

	case protocol.MsgTypeLeaderboardGet:
		leaderboard, err := db.GetLeaderboard()
		if err != nil {
			log.Printf("Leaderboard error: %v", err)
			return
		}

		response := protocol.NewMessage(protocol.MsgTypeLeaderboardData, leaderboard)
		bytes, _ := json.Marshal(response)
		c.Send <- bytes
		return

	case protocol.MsgTypeFriendRequest:
		var targetID string // Simple data, could wrap in struct
		json.Unmarshal(baseMsg.Data, &targetID)
		if err := db.AddFriend(c.ID, targetID); err != nil {
			log.Printf("Friend request error: %v", err)
			return
		}
		return

	case protocol.MsgTypeFriendAccept:
		var targetID string
		json.Unmarshal(baseMsg.Data, &targetID)
		if err := db.AcceptFriend(c.ID, targetID); err != nil {
			log.Printf("Friend accept error: %v", err)
			return
		}
		m.addFriendListResponse(c)
		return

	case protocol.MsgTypeFriendList:
		m.addFriendListResponse(c)
		return

	case protocol.MsgTypeChallengesGet:
		if !config.GetFeatureFlags().EnableDailyChallenges {
			m.sendError(c, "FEATURE_DISABLED", "Daily Challenges are currently disabled")
			return
		}
		status, err := db.GetDailyChallengesStatus(c.ID)
		if err != nil {
			log.Printf("Challenges error: %v", err)
			return
		}
		msg := protocol.NewMessage(protocol.MsgTypeChallengesData, status)
		bytes, _ := json.Marshal(msg)
		c.Send <- bytes
		return

	case protocol.MsgTypeChallengeClaim:
		if !config.GetFeatureFlags().EnableDailyChallenges {
			m.sendError(c, "FEATURE_DISABLED", "Daily Challenges are currently disabled")
			return
		}
		var challengeID string
		json.Unmarshal(baseMsg.Data, &challengeID)
		reward, err := db.ClaimChallengeReward(c.ID, challengeID)
		if err != nil {
			m.sendError(c, "CLAIM_FAILED", err.Error())
			return
		}

		response := map[string]interface{}{
			"challengeId": challengeID,
			"reward":      reward,
		}
		msg := protocol.NewMessage(protocol.MsgTypeChallengeClaimOk, response)
		bytes, _ := json.Marshal(msg)
		c.Send <- bytes

		// Also send AuthOk to refresh player coin balance
		stats, err := db.GetOrCreateUser(c.ID, "")
		if err == nil {
			m.sendAuthOk(c, stats)
		}
		return

	case "JOIN_ROOM":
		// Public Matchmaking
		if c.CurrentRoom == nil {
			c.IsSpectator = false // Ensure they are a player for public matches
			m.Queue.Add(c)
		} else {
			c.CurrentRoom.ForceBroadcastState()
		}
		return

	case protocol.MsgTypeCreatePrivateRoom:
		var payload protocol.CreatePrivateRoomMessage
		if err := json.Unmarshal(baseMsg.Data, &payload); err != nil {
			log.Printf("Create Room parse error: %v", err)
			return
		}
		m.createPrivateRoom(c, payload)
		return

	case protocol.MsgTypeJoinPrivateRoom:
		var payload protocol.JoinPrivateRoomMessage
		if err := json.Unmarshal(baseMsg.Data, &payload); err != nil {
			log.Printf("Join Room parse error: %v", err)
			return
		}
		m.joinPrivateRoom(c, payload)
		return
	case protocol.MsgTypeLeaveRoom:
		m.Queue.Remove(c) // Ensure removal from matchmaking if they were in queue
		if c.CurrentRoom != nil {
			c.CurrentRoom.Leave(c)
			c.CurrentRoom = nil
		}
		return
	case protocol.MsgTypeDeleteAccount:
		log.Printf("User %s requested account deletion", c.ID)
		if err := db.DeleteUser(c.ID); err != nil {
			log.Printf("Error deleting user: %v", err)
			m.sendError(c, "DELETE_FAILED", "Could not delete account data")
			return
		}
		// Confirm and disconnect
		m.sendError(c, "ACCOUNT_DELETED", "Your account has been permanently deleted")
		// Force disconnect
		if c.CurrentRoom != nil {
			c.CurrentRoom.Leave(c)
		}
		return
	}

	// 3. Room-scoped Handlers (Play, Pass, etc)
	if c.CurrentRoom != nil {
		c.CurrentRoom.HandleAction(GameAction{
			Client:  c,
			Message: baseMsg,
		})
	} else {
		// Error: Not in room
		errBytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeError, protocol.ErrorMessage{
			Code:    "NO_ROOM",
			Message: "You must join a room first",
		}))
		c.Send <- errBytes
	}
}

func (m *Manager) addFriendListResponse(c *Client) {
	friends, err := db.GetFriends(c.ID)
	if err != nil {
		log.Printf("Friend list error: %v", err)
		return
	}

	msg := protocol.NewMessage(protocol.MsgTypeFriendList, friends)
	bytes, _ := json.Marshal(msg)
	c.Send <- bytes
}

// -- Private Room Logic --

func (m *Manager) createPrivateRoom(c *Client, data protocol.CreatePrivateRoomMessage) {
	if c.CurrentRoom != nil {
		// Already in a room
		return
	}

	code := m.generateRoomCode()
	roomID := fmt.Sprintf("private_%s_%d", code, time.Now().Unix())

	r := NewPrivateRoom(roomID, data.RoomName, code, data.Password, c.ID, data.MaxPlayers, data.BootAmount)
	m.Rooms[code] = r
	// Optionally also store by ID if needed, but Code is primary for joining.

	go r.Run()

	log.Printf("Created Private Room %s (%s) for host %s", data.RoomName, code, c.ID)

	// Send Room Created Success
	response := map[string]interface{}{
		"roomCode": code,
		"roomId":   roomID,
		"roomName": data.RoomName,
		"hostId":   c.ID,
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeRoomCreated, response))
	c.Send <- bytes

	// Auto-join the creator
	c.CurrentRoom = r
	r.Join(c)
}

func (m *Manager) joinPrivateRoom(c *Client, data protocol.JoinPrivateRoomMessage) {
	if c.CurrentRoom != nil {
		m.sendError(c, "ALREADY_IN_ROOM", "You are already in a room")
		return
	}

	r, ok := m.Rooms[data.RoomCode]
	if !ok {
		m.sendError(c, "ROOM_NOT_FOUND", "Room not found")
		return
	}

	if !r.CheckPassword(data.Password) {
		m.sendError(c, "INVALID_PASSWORD", "Incorrect password")
		return
	}

	// Set Spectator Status
	c.IsSpectator = data.IsSpectator

	// Only check max players if NOT a spectator. Thread-safe check.
	if !c.IsSpectator && r.IsFull() {
		m.sendError(c, "ROOM_FULL", "Room is full")
		return
	}

	// Success
	c.CurrentRoom = r
	r.Join(c)

	// Send success message
	// Client receives ROOM_JOINED with room info.

	info := r.GetInfo()

	response := map[string]interface{}{
		"roomCode": info["roomCode"],
		"roomName": info["roomName"],
		"hostId":   info["hostId"],
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeRoomJoined, response))
	c.Send <- bytes
}

func (m *Manager) generateRoomCode() string {
	b := make([]byte, 6)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	// TODO: Check for collision
	return string(b)
}

func (m *Manager) sendError(c *Client, code, message string) {
	errBytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeError, protocol.ErrorMessage{
		Code:    code,
		Message: message,
	}))
	select {
	case c.Send <- errBytes:
	default:
	}
}

func (m *Manager) sendAuthOk(c *Client, stats *db.UserStats) {
	// Check if this user is a server admin
	isAdmin := false
	adminUIDsEnv := os.Getenv("ADMIN_UIDS")

	if adminUIDsEnv != "" {
		allowedUIDs := strings.Split(adminUIDsEnv, ",")
		trimmedClientUID := strings.TrimSpace(c.ID)

		for _, uid := range allowedUIDs {
			trimmedEnvUID := strings.TrimSpace(uid)
			if trimmedEnvUID == trimmedClientUID {
				isAdmin = true
				log.Printf("ADMIN_FOUND: Matched admin UID: %s", c.ID)
				break
			}
		}
	}

	responseMap := map[string]interface{}{
		"playerId":   c.ID,
		"stats":      stats,
		"serverTime": time.Now(),
		"isAdmin":    isAdmin,
	}

	msg := protocol.NewMessage(protocol.MsgTypeAuthOk, responseMap)
	bytes, _ := json.Marshal(msg)
	c.Send <- bytes
}

// GetActiveRooms returns a snapshot of all rooms
func (m *Manager) GetActiveRooms() []ActiveRoomInfo {
	// 1. Copy room pointers briefly under a read lock
	m.mu.RLock()
	roomsCopy := make(map[string]*Room)
	for id, r := range m.Rooms {
		roomsCopy[id] = r
	}
	m.mu.RUnlock()

	// 2. Iterate outside the manager lock to fetch room-level info
	// This prevents one slow/locked room from blocking the entire manager
	var list []ActiveRoomInfo
	for id, r := range roomsCopy {
		info := ActiveRoomInfo{
			ID:          id,
			PlayerCount: r.GetClientCount(),
			Phase:       r.GetGamePhase(),
			PlayerIDs:   r.GetPlayerIDs(),
		}
		list = append(list, info)
	}
	return list
}

// BroadcastSystemMessage sends a popup alert to every single connected player
func (m *Manager) BroadcastSystemMessage(message string) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	msg := protocol.NewMessage(protocol.MsgTypeSystemAlert, map[string]string{
		"message": message,
	})
	bytes, _ := json.Marshal(msg)

	for client := range m.Clients {
		select {
		case client.Send <- bytes:
		default:
			// Client's buffer full, handled by Run's unregister logic
		}
	}
}

// KickUser disconnects a specific user by ID
func (m *Manager) KickUser(userID string, reason string) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	msg := protocol.NewMessage(protocol.MsgTypeError, protocol.ErrorMessage{
		Code:    "KICKED",
		Message: reason,
	})
	bytes, _ := json.Marshal(msg)

	for client := range m.Clients {
		if client.ID == userID {
			// 1. Send reason
			client.Send <- bytes
			// 2. We don't close here to allow the client to read the error.
			// The socket handler will eventually close after send or we can force it.
			// Actually, closing the channel is safer.
			log.Printf("Kicking user %s: %s", userID, reason)
			// Small delay to let them see why they are kicked
			go func(c *Client) {
				time.Sleep(500 * time.Millisecond)
				m.Unregister <- c
			}(client)
		}
	}
}
