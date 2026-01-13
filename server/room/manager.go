package room

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"
	"veil_server/config"
	"veil_server/db"
	"veil_server/protocol"

	"firebase.google.com/go/v4/auth"
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
	ActiveLobbyCount     int
	ActiveLobbyStartTime time.Time

	AuthClient *auth.Client

	// Modular handlers (extracted for single-responsibility)
	authHandler *AuthHandler
	matchmaker  *Matchmaker
}

func NewManager(authClient *auth.Client) *Manager {
	m := &Manager{
		Clients:    make(map[*Client]bool),
		Register:   make(chan *Client, 256), // Buffered to prevent blocking
		Unregister: make(chan *Client, 256),
		Rooms:      make(map[string]*Room),
		AuthClient: authClient,
	}
	// Initialize modular handlers
	m.authHandler = NewAuthHandler(m)
	m.matchmaker = NewMatchmaker(m)
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
					// If they are leaving the currently filling lobby, free up a slot
					m.mu.Lock()
					// Safe Decrement: Only if they are actually in the lobby that is still filling
					if m.ActiveLobby != nil && client.CurrentRoom == m.ActiveLobby {
						m.ActiveLobbyCount--
						if m.ActiveLobbyCount < 0 {
							m.ActiveLobbyCount = 0
						}
						log.Printf("Lobby slot freed. Remaining: %d", m.ActiveLobbyCount)
					}
					m.mu.Unlock()

					// ✅ FIX: Run Leave in background to not block Manager
					// This prevents registration timeouts when Leave is slow
					go client.CurrentRoom.Leave(client)
				}
				if !client.IsBot {
					close(client.Send)
				}
				log.Println("Connection Unregistered")
			}

		case <-ticker.C:
			// Regular Housekeeping
			m.matchmaker.CheckLobbyTimeout()
			m.matchmaker.CleanupEmptyRooms()
		}
	}
}

// DELEGATED to Matchmaker

// DELEGATED to Matchmaker but wrapper kept for Interface Compliance
func (m *Manager) AttemptJoinActiveLobby(c *Client) {
	m.matchmaker.AttemptJoinActiveLobby(c)
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
		m.authHandler.HandleAuth(c, authData)
		return

	case protocol.MsgTypeUpdateName:
		m.authHandler.HandleUpdateName(c, baseMsg.Data)
		return

	case protocol.MsgTypeRefillCoins:
		m.authHandler.HandleRefillCoins(c)
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
		m.authHandler.AddFriendListResponse(c)
		return

	case protocol.MsgTypeFriendList:
		m.authHandler.AddFriendListResponse(c)
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
		m.authHandler.HandleChallengeClaim(c, baseMsg.Data)
		return

	case "JOIN_ROOM":
		// Public Realtime Matchmaking
		if c.CurrentRoom == nil {
			c.IsSpectator = false
			// Join the active lobby IMMEDIATELY
			m.matchmaker.AttemptJoinActiveLobby(c)
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
		if c.CurrentRoom != nil {
			m.mu.Lock()
			if m.ActiveLobby != nil && c.CurrentRoom == m.ActiveLobby {
				m.ActiveLobbyCount--
				if m.ActiveLobbyCount < 0 {
					m.ActiveLobbyCount = 0
				}
				log.Printf("Manual Leave: Lobby slot freed. Remaining: %d", m.ActiveLobbyCount)
			}
			m.mu.Unlock()

			c.CurrentRoom.Leave(c)
			c.CurrentRoom = nil
		}
		return

	case protocol.MsgTypeDeleteAccount:
		m.authHandler.HandleDeleteAccount(c)
		return

	case "PING":
		// Heartbeat - respond with PONG (no room required)
		pongBytes, _ := json.Marshal(protocol.NewMessage("PONG", nil))
		select {
		case c.Send <- pongBytes:
		default:
		}
		return

	case protocol.MsgTypeUpdateFCM:
		// Just log it for now, or update DB if we had a field for it
		// This prevents "You must join a room first" error
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

// DELEGATED to AuthHandler (handleAuth, handleUpdateName, handleRefillCoins, handleChallengeClaim, handleDeleteAccount, addFriendListResponse)

// -- Room Logic --

func (m *Manager) createPrivateRoom(c *Client, data protocol.CreatePrivateRoomMessage) {
	if c.CurrentRoom != nil {
		return // Already in a room
	}

	code := m.matchmaker.GenerateRoomCode()
	roomID := fmt.Sprintf("private_%s_%d", code, time.Now().Unix())

	r := NewPrivateRoom(roomID, data.RoomName, code, data.Password, c.ID, data.MaxPlayers, data.BootAmount)

	m.mu.Lock()
	m.Rooms[code] = r
	m.mu.Unlock()

	go r.Run()

	log.Printf("Created Private Room %s (%s)", data.RoomName, code)

	response := map[string]interface{}{
		"roomCode":  code,
		"roomId":    roomID,
		"roomName":  data.RoomName,
		"hostId":    c.ID,
		"createdAt": r.CreationTime,
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

	m.mu.RLock()
	r, ok := m.Rooms[data.RoomCode]
	m.mu.RUnlock()

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
		"roomCode":  info["roomCode"],
		"roomName":  info["roomName"],
		"hostId":    info["hostId"],
		"createdAt": info["createdAt"],
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeRoomJoined, response))
	c.Send <- bytes
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

// DELEGATED to Matchmaker

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
