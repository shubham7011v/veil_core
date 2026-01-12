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

	// Active Lobby State
	ActiveLobby          *Room
	ActiveLobbyStartTime time.Time

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
	// No more Queue initialization
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
				// No need to remove from Queue.
				// The client is always in a Room now (ActiveLobby or GameRoom).
				if client.CurrentRoom != nil {
					client.CurrentRoom.Leave(client)
				}
				if !client.IsBot {
					close(client.Send)
				}
				log.Println("Connection Unregistered")
			}

		case <-ticker.C:
			// Regular Housekeeping and Lobby Timeout Check
			m.checkLobbyTimeout()
		}
	}
}

// checkLobbyTimeout checks if the active lobby has waited too long (10s)
// and needs to be filled with bots to start the game.
func (m *Manager) checkLobbyTimeout() {
	m.mu.Lock()
	defer m.mu.Unlock()

	lobby := m.ActiveLobby
	if lobby == nil {
		return
	}

	// Check if lobby is still valid/open (sanity check)
	if lobby.GetGamePhase() != "Lobby" || lobby.IsFull() {
		m.ActiveLobby = nil
		return
	}

	// Constants
	const LobbyTimeout = 10 * time.Second
	const TargetPlayers = 5

	if time.Since(m.ActiveLobbyStartTime) > LobbyTimeout {
		// Timeout Reached! Fill with Bots.
		if !config.GetFeatureFlags().EnableBotPlayers {
			// If bots disabled, just leave it open indefinitely?
			// Or maybe force start with < 5?
			// For now, let's just log and wait if bots are disabled.
			return
		}

		currentCount := lobby.GetClientCount()
		botsNeeded := TargetPlayers - currentCount

		// Don't spawn if full (should use IsFull check above, but double check)
		if botsNeeded <= 0 {
			m.ActiveLobby = nil
			return // Should have auto-started
		}

		log.Printf("Lobby Timeout: Spawning %d bots for Room %s", botsNeeded, lobby.ID)

		// Spawn Bots
		for i := 0; i < botsNeeded; i++ {
			bot := NewBot(m)
			bot.CurrentRoom = lobby
			lobby.Join(bot.Client)
		}

		// Seal the lobby so no new humans join this bot-filled game
		m.ActiveLobby = nil
	}
}

// AttemptJoinActiveLobby handles robust locking to put the client in the current open room
func (m *Manager) AttemptJoinActiveLobby(c *Client) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// 1. Validate if we have a valid ActiveLobby
	if m.ActiveLobby != nil {
		// Check if it is actually full or started (dirty read protection)
		if m.ActiveLobby.IsFull() || m.ActiveLobby.GetGamePhase() != "Lobby" {
			m.ActiveLobby = nil
		}
	}

	// 2. Create if missing
	if m.ActiveLobby == nil {
		roomID := fmt.Sprintf("match_%d", time.Now().UnixNano())
		room := NewRoom(roomID)
		m.Rooms[roomID] = room

		go room.Run() // Start the room loop

		m.ActiveLobby = room
		m.ActiveLobbyStartTime = time.Now()
		log.Printf("Created New Active Lobby: %s", roomID)
	}

	// 3. Join
	c.CurrentRoom = m.ActiveLobby
	m.ActiveLobby.Join(c)

	// 4. Check if we just filled it
	// Note: We need a direct check here because the room loop runs async.
	// But based on our "IsFull" logic which locks the room, we can check it.
	// However, simplistically, we can just check if client count reached max.
	// We'll leave it to the next joining attempt or ticker to clear 'ActiveLobby'
	// if it became full, OR we can preemptively clear it if we know we hit 5.
	// Let's rely on the check at step 1 for the next joiner, or the Ticker,
	// unless we want to be super strict.
	// Optimistic approach: Stick to step 1 check.
}

// HandleMessage routes incoming messages from clients
func (m *Manager) HandleMessage(c *Client, message []byte) {
	// 1. Parse ONLY the type first
	var baseMsg protocol.BaseMessage
	if err := json.Unmarshal(message, &baseMsg); err != nil {
		log.Printf("Invalid JSON: %v", err)
		return
	}

	// 2. Global Handlers (Auth, Join Room)
	switch baseMsg.Type {
	case protocol.MsgTypeAuth:
		var authData protocol.AuthMessage
		if err := json.Unmarshal(baseMsg.Data, &authData); err != nil {
			log.Printf("Auth unmarshal error: %v", err)
			return
		}
		m.handleAuth(c, authData)
		return

	case protocol.MsgTypeUpdateName:
		m.handleUpdateName(c, baseMsg.Data)
		return

	case protocol.MsgTypeRefillCoins:
		m.handleRefillCoins(c)
		return

	case protocol.MsgTypeLeaderboardGet:
		leaderboard, err := db.GetLeaderboard()
		if err == nil {
			bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeLeaderboardData, leaderboard))
			c.Send <- bytes
		}
		return

	case protocol.MsgTypeFriendRequest:
		var targetID string
		json.Unmarshal(baseMsg.Data, &targetID)
		db.AddFriend(c.ID, targetID)
		return

	case protocol.MsgTypeFriendAccept:
		var targetID string
		json.Unmarshal(baseMsg.Data, &targetID)
		db.AcceptFriend(c.ID, targetID)
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
		status, _ := db.GetDailyChallengesStatus(c.ID)
		bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeChallengesData, status))
		c.Send <- bytes
		return

	case protocol.MsgTypeChallengeClaim:
		m.handleChallengeClaim(c, baseMsg.Data)
		return

	case "JOIN_ROOM":
		// Public Realtime Matchmaking
		if c.CurrentRoom == nil {
			c.IsSpectator = false
			// Join the active lobby IMMEDIATELY
			m.AttemptJoinActiveLobby(c)
		} else {
			c.CurrentRoom.ForceBroadcastState()
		}
		return

	case protocol.MsgTypeCreatePrivateRoom:
		var payload protocol.CreatePrivateRoomMessage
		if err := json.Unmarshal(baseMsg.Data, &payload); err == nil {
			m.createPrivateRoom(c, payload)
		}
		return

	case protocol.MsgTypeJoinPrivateRoom:
		var payload protocol.JoinPrivateRoomMessage
		if err := json.Unmarshal(baseMsg.Data, &payload); err == nil {
			m.joinPrivateRoom(c, payload)
		}
		return

	case protocol.MsgTypeLeaveRoom:
		// Logic handled via Client.Leave/Unregister, but explicit allow:
		if c.CurrentRoom != nil {
			c.CurrentRoom.Leave(c)
			c.CurrentRoom = nil
		}
		return

	case protocol.MsgTypeDeleteAccount:
		m.handleDeleteAccount(c)
		return
	}

	// 3. Room-scoped Handlers
	if c.CurrentRoom != nil {
		c.CurrentRoom.HandleAction(GameAction{
			Client:  c,
			Message: baseMsg,
		})
	} else {
		m.sendError(c, "NO_ROOM", "You must join a room first")
	}
}

// ----------------------------------------------------------------------
// Helper Handlers (Refactored from giant switch for readability)
// ----------------------------------------------------------------------

func (m *Manager) handleAuth(c *Client, authData protocol.AuthMessage) {
	tokenString := authData.Token
	userName := authData.Name
	userID := tokenString
	firebaseName := userName
	firebaseAvatar := authData.AvatarURL

	if m.AuthClient != nil && !strings.HasPrefix(tokenString, "mock_") {
		token, err := m.AuthClient.VerifyIDToken(context.Background(), tokenString)
		if err == nil {
			userID = token.UID
			if firebaseName == "" && token.Claims["name"] != nil {
				firebaseName = token.Claims["name"].(string)
			}
			if firebaseAvatar == "" && token.Claims["picture"] != nil {
				firebaseAvatar = token.Claims["picture"].(string)
			}
		} else {
			log.Printf("Token verify failed: %v", err)
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

	stats, err := db.GetOrCreateUser(c.ID, firebaseName)
	if err == nil {
		if firebaseAvatar != "" {
			db.UpdateUserAvatar(c.ID, firebaseAvatar)
			stats.AvatarURL = firebaseAvatar
		}
	} else {
		stats = &db.UserStats{UserID: c.ID, Name: "Unknown", Rank: "Novice", Coins: 1000}
	}
	m.sendAuthOk(c, stats)
}

func (m *Manager) handleUpdateName(c *Client, data []byte) {
	var payload protocol.UpdateNameMessage
	if err := json.Unmarshal(data, &payload); err != nil {
		return
	}
	if err := db.UpdateUserName(c.ID, payload.Name); err != nil {
		return
	}
	stats, _ := db.GetOrCreateUser(c.ID, payload.Name)
	m.sendAuthOk(c, stats)
}

func (m *Manager) handleRefillCoins(c *Client) {
	stats, _ := db.GetOrCreateUser(c.ID, "")
	if stats.Coins < 100 {
		topUp := 1000 - stats.Coins
		if err := db.UpdateUserCoins(c.ID, topUp); err == nil {
			stats.Coins = 1000
			m.sendAuthOk(c, stats)
		}
	} else {
		m.sendError(c, "REFILL_DENIED", "You have enough coins!")
	}
}

func (m *Manager) handleChallengeClaim(c *Client, data []byte) {
	if !config.GetFeatureFlags().EnableDailyChallenges {
		m.sendError(c, "FEATURE_DISABLED", "Daily Challenges are currently disabled")
		return
	}
	var challengeID string
	json.Unmarshal(data, &challengeID)
	reward, err := db.ClaimChallengeReward(c.ID, challengeID)
	if err != nil {
		m.sendError(c, "CLAIM_FAILED", err.Error())
		return
	}

	response := map[string]interface{}{
		"challengeId": challengeID,
		"reward":      reward,
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeChallengeClaimOk, response))
	c.Send <- bytes

	stats, err := db.GetOrCreateUser(c.ID, "")
	if err == nil {
		m.sendAuthOk(c, stats)
	}
}

func (m *Manager) handleDeleteAccount(c *Client) {
	log.Printf("User %s requested account deletion", c.ID)
	if err := db.DeleteUser(c.ID); err != nil {
		m.sendError(c, "DELETE_FAILED", "Could not delete account data")
		return
	}
	m.sendError(c, "ACCOUNT_DELETED", "Your account has been permanently deleted")
	if c.CurrentRoom != nil {
		c.CurrentRoom.Leave(c)
	}
}

func (m *Manager) addFriendListResponse(c *Client) {
	friends, err := db.GetFriends(c.ID)
	if err != nil {
		return
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeFriendList, friends))
	c.Send <- bytes
}

// -- Room Logic --

func (m *Manager) createPrivateRoom(c *Client, data protocol.CreatePrivateRoomMessage) {
	if c.CurrentRoom != nil {
		return // Already in a room
	}

	code := m.generateRoomCode()
	roomID := fmt.Sprintf("private_%s_%d", code, time.Now().Unix())

	r := NewPrivateRoom(roomID, data.RoomName, code, data.Password, c.ID, data.MaxPlayers, data.BootAmount)
	m.Rooms[code] = r
	go r.Run()

	log.Printf("Created Private Room %s (%s)", data.RoomName, code)

	response := map[string]interface{}{
		"roomCode": code,
		"roomId":   roomID,
		"roomName": data.RoomName,
		"hostId":   c.ID,
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeRoomCreated, response))
	c.Send <- bytes

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

	c.IsSpectator = data.IsSpectator
	if !c.IsSpectator && r.IsFull() {
		m.sendError(c, "ROOM_FULL", "Room is full")
		return
	}

	c.CurrentRoom = r
	r.Join(c)

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
	isAdmin := false
	if adminUIDsEnv := os.Getenv("ADMIN_UIDS"); adminUIDsEnv != "" {
		for _, uid := range strings.Split(adminUIDsEnv, ",") {
			if strings.TrimSpace(uid) == strings.TrimSpace(c.ID) {
				isAdmin = true
				break
			}
		}
	}

	msg := protocol.NewMessage(protocol.MsgTypeAuthOk, map[string]interface{}{
		"playerId":   c.ID,
		"stats":      stats,
		"serverTime": time.Now(),
		"isAdmin":    isAdmin,
	})
	bytes, _ := json.Marshal(msg)
	c.Send <- bytes
}

// GetActiveRooms returns a snapshot of all rooms
func (m *Manager) GetActiveRooms() []ActiveRoomInfo {
	m.mu.RLock()
	roomsCopy := make(map[string]*Room)
	for id, r := range m.Rooms {
		roomsCopy[id] = r
	}
	m.mu.RUnlock()

	var list []ActiveRoomInfo
	for id, r := range roomsCopy {
		list = append(list, ActiveRoomInfo{
			ID:          id,
			PlayerCount: r.GetClientCount(),
			Phase:       r.GetGamePhase(),
			PlayerIDs:   r.GetPlayerIDs(),
		})
	}
	return list
}

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
		}
	}
}

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
			client.Send <- bytes
			go func(c *Client) {
				time.Sleep(500 * time.Millisecond)
				m.Unregister <- c
			}(client)
		}
	}
}
