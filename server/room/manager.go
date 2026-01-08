package room

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"
	"veil_server/db"
	"veil_server/protocol"
)

const (
	charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excludes I, O, 0, 1
)

// ActiveRoomInfo for admin dashboard
type ActiveRoomInfo struct {
	ID          string `json:"id"`
	PlayerCount int    `json:"playerCount"`
	Phase       string `json:"phase"`
}

// Manager keeps track of all clients and rooms
type Manager struct {
	mu         sync.RWMutex
	Clients    map[*Client]bool
	Register   chan *Client
	Unregister chan *Client

	Rooms map[string]*Room
	Queue *MatchmakingQueue
}

func NewManager() *Manager {
	m := &Manager{
		Clients:    make(map[*Client]bool),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
		Rooms:      make(map[string]*Room),
	}
	m.Queue = NewMatchmakingQueue()
	return m
}

func (m *Manager) Run() {
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
			clients, matchType := m.Queue.Tick()
			if clients != nil {
				if matchType == "BOT" {
					// Spawn Bot
					bot := NewBot(m)
					clients = append(clients, bot.Client)
					log.Println("Spawning Bot for timeout match")
				}
				m.createMatchRoom(clients)
			}
		}
	}
}

func (m *Manager) createMatchRoom(clients []*Client) {
	roomID := fmt.Sprintf("match_%d", time.Now().UnixNano())
	room := NewRoom(roomID)
	m.Rooms[roomID] = room
	go room.Run()

	log.Printf("Starting Match Room %s with %d players", roomID, len(clients))

	for _, c := range clients {
		c.CurrentRoom = room
		room.Join(c)
	}

	// Wait briefly for registers then start
	go func() {
		time.Sleep(500 * time.Millisecond)
		startMsg := protocol.BaseMessage{Type: protocol.MsgTypeStartGame}
		// Send start triggering via first client
		room.HandleAction(GameAction{Client: clients[0], Message: startMsg})
	}()
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

		userID := authData.Token
		userName := authData.Name
		if userName == "" {
			userName = "Player " + userID[:4]
		}
		// Simplified mock detection
		if len(userID) > 20 && userID[:5] == "mock_" {
			userID = fmt.Sprintf("%s_%d", userID, time.Now().UnixNano()%10000)
		}

		c.ID = userID

		// Get Data from SQLite
		stats, err := db.GetOrCreateUser(c.ID, userName)
		if err != nil {
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
	responseMap := map[string]interface{}{
		"playerId":   c.ID,
		"stats":      stats,
		"serverTime": time.Now(),
	}

	msg := protocol.NewMessage(protocol.MsgTypeAuthOk, responseMap)
	bytes, _ := json.Marshal(msg)
	c.Send <- bytes
}

// GetActiveRooms returns a snapshot of all rooms
func (m *Manager) GetActiveRooms() []ActiveRoomInfo {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var list []ActiveRoomInfo
	for id, r := range m.Rooms {
		info := ActiveRoomInfo{
			ID:          id,
			PlayerCount: r.GetClientCount(),
			Phase:       r.GetGamePhase(),
		}
		list = append(list, info)
	}
	return list
}
