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

	"sync/atomic"

	"firebase.google.com/go/v4/auth"
)

// ActiveRoomInfo for admin dashboard
type ActiveRoomInfo struct {
	ID          string   `json:"id"`
	PlayerCount int      `json:"playerCount"`
	Phase       string   `json:"phase"`
	PlayerIDs   []string `json:"playerIds"`
}

// ManagerStatus for observability
type ManagerStatus struct {
	TotalClients     int    `json:"totalClients"`
	TotalRooms       int    `json:"totalRooms"`
	PlayerRoomCount  int    `json:"playerRoomCount"`
	ActiveLobbyCount int    `json:"activeLobbyCount"`
	ActiveLobbyID    string `json:"activeLobbyId,omitempty"`
	LoopLag          int64  `json:"loopLag"` // Seconds since last iteration
	Uptime           int64  `json:"uptime"`  // Seconds since start
}

// Manager keeps track of all clients and rooms
type Manager struct {
	mu              sync.RWMutex
	Clients         map[*Client]bool
	Register        chan *Client
	Unregister      chan *Client
	ExpiredSessions chan string // Channel for Rooms to enforce index cleanup

	Rooms       map[string]*Room
	PlayerRooms map[string]*Room // O(1) Lookup: playerID -> *Room

	// Active Lobby State
	ActiveLobby          *Room
	ActiveLobbyCount     int
	ActiveLobbyStartTime time.Time

	AuthClient *auth.Client

	// Modular handlers (extracted for single-responsibility)
	authHandler *AuthHandler
	matchmaker  *Matchmaker

	lastLoopTime int64 // Unix timestamp (monitored via atomic)
	CreationTime time.Time
}

func NewManager(authClient *auth.Client) *Manager {
	m := &Manager{
		Clients:         make(map[*Client]bool),
		Register:        make(chan *Client, 1024), // Increased buffer to prevent blocking
		Unregister:      make(chan *Client, 1024),
		ExpiredSessions: make(chan string, 1024),

		Rooms:        make(map[string]*Room),
		PlayerRooms:  make(map[string]*Room),
		AuthClient:   authClient,
		CreationTime: time.Now(),
	}
	// Initialize modular handlers
	m.authHandler = NewAuthHandler(m)
	m.matchmaker = NewMatchmaker(m)

	m.startDeadlockMonitor()
	return m
}

func (m *Manager) startDeadlockMonitor() {
	go func() {
		for {
			time.Sleep(10 * time.Second)
			last := atomic.LoadInt64(&m.lastLoopTime)
			if last > 0 {
				elapsed := time.Now().Unix() - last
				if elapsed > 15 {
					log.Printf("CRITICAL: Manager.Run loop has not iterated for %ds! Potential deadlock or heavy blocking.", elapsed)
				}
			}
		}
	}()
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
		atomic.StoreInt64(&m.lastLoopTime, time.Now().Unix())
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
					// NOTE: We do NOT remove from PlayerRooms here anymore.
					// We wait for the Room to signal expiry via ExpiredSessions.

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
				// ✅ FIX #2: Always close Send channel (including bots) to prevent goroutine leaks
				close(client.Send)
				log.Println("Connection Unregistered")
			}

		case playerID := <-m.ExpiredSessions:
			// Cleanup from Index
			m.RemovePlayerRoom(playerID)

		case <-ticker.C:
			// Regular Housekeeping
			m.matchmaker.CheckLobbyTimeout()
			m.matchmaker.CleanupEmptyRooms()
		}
	}
}

// Shutdown stops all active rooms and cleans up resources
func (m *Manager) Shutdown() {
	m.mu.Lock()
	defer m.mu.Unlock()

	log.Printf("Manager: Shutting down %d rooms", len(m.Rooms))
	for _, r := range m.Rooms {
		r.Stop()
	}
}

// DELEGATED to Matchmaker

// DELEGATED to Matchmaker but wrapper kept for Interface Compliance
func (m *Manager) AttemptJoinActiveLobby(c *Client) {
	m.matchmaker.AttemptJoinActiveLobby(c)
}

// SetPlayerRoom updates the O(1) index
func (m *Manager) SetPlayerRoom(playerID string, r *Room) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.PlayerRooms[playerID] = r
}

// RemovePlayerRoom removes the player from the O(1) index
func (m *Manager) RemovePlayerRoom(playerID string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.PlayerRooms, playerID)
}

// FindRoomByPlayerID uses the indexed map for O(1) lookup
func (m *Manager) FindRoomByPlayerID(playerID string) *Room {
	m.mu.RLock()
	defer m.mu.RUnlock()

	return m.PlayerRooms[playerID]
}

// HandleMessage routes incoming messages from clients
func (m *Manager) HandleMessage(c *Client, message []byte) {
	// 1. Parse ONLY the type first
	var baseMsg protocol.BaseMessage
	if err := json.Unmarshal(message, &baseMsg); err != nil {
		log.Printf("Invalid JSON: %v", err)
		return
	}

	// ✅ FIX #8: Action Sequence Validation
	// If a sequence is provided, ensure it's not an old/replayed message
	if baseMsg.Sequence > 0 {
		c.mu.Lock()
		if baseMsg.Sequence <= c.lastSequence {
			log.Printf("DROPPING: Out of order message from %s (Type: %s, Seq: %d, Last: %d)",
				c.ID, baseMsg.Type, baseMsg.Sequence, c.lastSequence)
			c.mu.Unlock()
			return
		}
		c.lastSequence = baseMsg.Sequence
		c.mu.Unlock()
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

	case protocol.MsgTypeMatchHistoryGet:
		history, err := db.GetUserMatchHistory(c.ID)
		if err == nil {
			bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeMatchHistoryData, history))
			c.Send <- bytes
		}
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

	case protocol.MsgTypeJoinRoom:
		// Public Realtime Matchmaking
		if c.CurrentRoom == nil {
			// ✅ Session Restoration: Check if they are already in an active room
			if r := m.FindRoomByPlayerID(c.ID); r != nil {
				log.Printf("Session Restoration: Player %s found in active room %s", c.ID, r.ID)
				c.CurrentRoom = r
				r.Join(c)
				return
			}

			c.IsSpectator = false
			// Join the active lobby IMMEDIATELY
			m.matchmaker.AttemptJoinActiveLobby(c)
		} else {
			c.CurrentRoom.ForceBroadcastState()
		}
		return

	case protocol.MsgTypeCancelMatchmaking:
		if c.CurrentRoom != nil {
			m.mu.Lock()
			// Only allow cancellation if in ActiveLobby (matchmaking)
			if m.ActiveLobby != nil && c.CurrentRoom == m.ActiveLobby {
				log.Printf("Matchmaking: Client %s cancelled matchmaking", c.ID)
				m.ActiveLobbyCount--
				if m.ActiveLobbyCount < 0 {
					m.ActiveLobbyCount = 0
				}
				m.mu.Unlock()

				c.CurrentRoom.Leave(c)
				c.CurrentRoom = nil
				m.RemovePlayerRoom(c.ID)
			} else {
				m.mu.Unlock()
			}
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

			// ✅ FIX: Force room to process permanent leave (bypass grace period)
			c.CurrentRoom.HandleAction(GameAction{
				Client:  c,
				Message: baseMsg,
			})

			c.CurrentRoom.Leave(c)
			c.CurrentRoom = nil
			m.RemovePlayerRoom(c.ID) // Clear the index so they aren't restored
		}
		return

	case protocol.MsgTypeDeleteAccount:
		m.authHandler.HandleDeleteAccount(c)
		return

	case protocol.MsgTypePing:
		// Heartbeat - respond with PONG (no room required)
		// ✅ FIX: Use protocol constant and ensure PONG is sent
		bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypePong, nil))
		select {
		case c.Send <- bytes:
		case <-time.After(100 * time.Millisecond):
			log.Printf("Heartbeat: Failed to send PONG to %s (buffer full)", c.ID)
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
	r.SessionExpiry = m.ExpiredSessions

	// Set cleanup callback
	r.OnStop = func() {
		m.mu.Lock()
		delete(m.Rooms, code)
		m.mu.Unlock()
		log.Printf("Manager: Cleaned up private room %s after stop", code)
	}

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
	m.SetPlayerRoom(c.ID, r)
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
	m.SetPlayerRoom(c.ID, r)
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

// GetStatus returns a snapshot of manager health and load
func (m *Manager) GetStatus() ManagerStatus {
	m.mu.RLock()
	defer m.mu.RUnlock()

	last := atomic.LoadInt64(&m.lastLoopTime)
	lag := int64(0)
	if last > 0 {
		lag = time.Now().Unix() - last
	}

	activeLobbyID := ""
	if m.ActiveLobby != nil {
		activeLobbyID = m.ActiveLobby.ID
	}

	return ManagerStatus{
		TotalClients:     len(m.Clients),
		TotalRooms:       len(m.Rooms),
		PlayerRoomCount:  len(m.PlayerRooms),
		ActiveLobbyCount: m.ActiveLobbyCount,
		ActiveLobbyID:    activeLobbyID,
		LoopLag:          lag,
		Uptime:           int64(time.Since(m.CreationTime).Seconds()),
	}
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
