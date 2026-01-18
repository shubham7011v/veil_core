package room

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"
	"veil_server/config"
	"veil_server/internal/domain/user"
	"veil_server/internal/infrastructure/firebase"
	"veil_server/internal/infrastructure/sqlite"
	authUseCase "veil_server/internal/usecase/auth"
	economyUseCase "veil_server/internal/usecase/economy"
	gameUseCase "veil_server/internal/usecase/game"
	socialUseCase "veil_server/internal/usecase/social"
	"veil_server/internal/usecase/stats"
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

	// Repositories
	UserRepo user.Repository

	// UseCases
	statsUC   *stats.UseCase
	authUC    *authUseCase.UseCase
	socialUC  *socialUseCase.UseCase
	gameUC    *gameUseCase.UseCase
	economyUC *economyUseCase.UseCase

	lastLoopTime int64 // Unix timestamp (monitored via atomic)
	CreationTime time.Time
}

func NewManager(authClient *auth.Client, dbConn *sql.DB) *Manager {
	userRepo := sqlite.NewUserRepository(dbConn)
	mgr := &Manager{
		Clients:         make(map[*Client]bool),
		Register:        make(chan *Client, config.ManagerRegisterBuffer),
		Unregister:      make(chan *Client, config.ManagerUnregisterBuffer),
		ExpiredSessions: make(chan string, config.SessionExpiryBuffer),

		Rooms:        make(map[string]*Room),
		PlayerRooms:  make(map[string]*Room),
		AuthClient:   authClient,
		UserRepo:     userRepo,
		CreationTime: time.Now(),
	}

	// Adapters
	var idp authUseCase.IdentityProvider
	if authClient != nil {
		idp = firebase.NewAdapter(authClient)
	}

	// Initialize modular handlers
	mgr.authHandler = NewAuthHandler(mgr)
	mgr.matchmaker = NewMatchmaker(mgr, userRepo)
	mgr.statsUC = stats.NewUseCase(userRepo)
	mgr.authUC = authUseCase.NewUseCase(userRepo, idp)

	// Phase 5 Injections
	socialRepo := sqlite.NewSocialRepository(dbConn)
	challengeRepo := sqlite.NewChallengeRepository(dbConn)
	economyRepo := sqlite.NewEconomyRepository(dbConn)
	matchRepo := sqlite.NewMatchRepository(dbConn)

	mgr.socialUC = socialUseCase.NewUseCase(socialRepo)
	mgr.economyUC = economyUseCase.NewUseCase(economyRepo)
	mgr.gameUC = gameUseCase.NewUseCase(matchRepo, challengeRepo, economyRepo)

	// Start Background Workers (Replaces db package workers)
	mgr.startCoinFlusher(economyRepo)
	mgr.startDailyResetWorker(challengeRepo)

	mgr.startDeadlockMonitor()
	return mgr
}

func (mgr *Manager) startCoinFlusher(repo *sqlite.EconomyRepository) {
	go func() {
		ticker := time.NewTicker(60 * time.Second)
		for range ticker.C {
			if err := repo.FlushCoins(); err != nil {
				log.Printf("Error flushing coins from Manager: %v", err)
			}
		}
	}()
}

func (mgr *Manager) startDailyResetWorker(repo *sqlite.ChallengeRepository) {
	go func() {
		for {
			now := time.Now().UTC()
			next := now.Add(time.Hour * 24)
			next = time.Date(next.Year(), next.Month(), next.Day(), 0, 0, 0, 0, time.UTC)
			t := time.NewTimer(next.Sub(now))

			log.Printf("Daily Challenge Reset scheduled for %v", next)
			<-t.C

			if err := repo.ResetDailyProgress(); err != nil {
				log.Printf("CRITICAL: Failed to reset daily challenges from Manager: %v", err)
			} else {
				log.Println("SUCCESS: Daily challenges have been reset via Manager.")
			}
		}
	}()
}

func (mgr *Manager) startDeadlockMonitor() {
	go func() {
		for {
			time.Sleep(10 * time.Second)
			last := atomic.LoadInt64(&mgr.lastLoopTime)
			if last > 0 {
				elapsed := time.Now().Unix() - last
				if elapsed > config.DeadlockThresholdSec {
					log.Printf("CRITICAL: Manager.Run loop has not iterated for %ds! Potential deadlock or heavy blocking.", elapsed)
				}
			}
		}
	}()
}

func (mgr *Manager) Run() {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Manager Recovered from panic: %v", r)
			go mgr.Run() // Restart
		}
	}()

	ticker := time.NewTicker(time.Duration(config.ManagerTickIntervalSec) * time.Second)
	defer ticker.Stop()

	for {
		atomic.StoreInt64(&mgr.lastLoopTime, time.Now().Unix())
		select {
		case client := <-mgr.Register:
			mgr.Clients[client] = true
			log.Println("New Connection Registered")

		case client := <-mgr.Unregister:
			if _, ok := mgr.Clients[client]; ok {
				delete(mgr.Clients, client)
				// No need to remove from Queue.
				// The client is always in a Room now (ActiveLobby or GameRoom).
				if client.CurrentRoom != nil {
					// NOTE: We do NOT remove from PlayerRooms here anymore.
					// We wait for the Room to signal expiry via ExpiredSessions.

					// If they are leaving the currently filling lobby, free up a slot
					mgr.mu.Lock()
					// Safe Decrement: Only if they are actually in the lobby that is still filling
					if mgr.ActiveLobby != nil && client.CurrentRoom == mgr.ActiveLobby {
						mgr.ActiveLobbyCount--
						if mgr.ActiveLobbyCount < 0 {
							mgr.ActiveLobbyCount = 0
						}
						log.Printf("Lobby slot freed. Remaining: %d", mgr.ActiveLobbyCount)
					}
					mgr.mu.Unlock()

					// ✅ FIX: Run Leave in background to not block Manager
					// This prevents registration timeouts when Leave is slow
					go client.CurrentRoom.Leave(client)
				}
				// ✅ FIX #2: Always close Send channel (including bots) to prevent goroutine leaks
				close(client.Send)
				log.Println("Connection Unregistered")
			}

		case playerID := <-mgr.ExpiredSessions:
			// Cleanup from Index
			mgr.RemovePlayerRoom(playerID)

		case <-ticker.C:
			// Regular Housekeeping
			mgr.matchmaker.CheckLobbyTimeout()
			mgr.matchmaker.CleanupEmptyRooms()
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

// ForceCloseRoom forcefully stops a specific room by ID (admin function)
func (m *Manager) ForceCloseRoom(roomID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	room, exists := m.Rooms[roomID]
	if !exists {
		return fmt.Errorf("room not found: %s", roomID)
	}

	log.Printf("Admin: Force closing room %s", roomID)

	// Notify all clients in the room before closing
	msg := protocol.NewMessage(protocol.MsgTypeSystemAlert, map[string]string{
		"message": "This room has been closed by an administrator.",
	})
	bytes, _ := json.Marshal(msg)

	room.mu.RLock()
	for client := range room.clients {
		select {
		case client.Send <- bytes:
		default:
			// Client buffer full, skip
		}
	}
	room.mu.RUnlock()

	// Stop the room (cleanup will happen via normal mechanisms)
	room.Stop()

	return nil
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
		leaderboard, err := m.statsUC.GetLeaderboard()
		if err == nil {
			bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeLeaderboardData, leaderboard))
			c.Send <- bytes
		}
		return

	case protocol.MsgTypeFriendRequest:
		var targetID string
		json.Unmarshal(baseMsg.Data, &targetID)
		m.socialUC.AddFriendRequest(c.ID, targetID)
		return

	case protocol.MsgTypeFriendAccept:
		var targetID string
		json.Unmarshal(baseMsg.Data, &targetID)
		m.socialUC.AcceptFriendRequest(c.ID, targetID)
		m.authHandler.AddFriendListResponse(c)
		return

	case protocol.MsgTypeFriendList:
		m.authHandler.AddFriendListResponse(c)
		return

	case protocol.MsgTypeMatchHistoryGet:
		history, err := m.statsUC.GetMatchHistory(c.ID)
		if err == nil {
			bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeMatchHistoryData, history))
			c.Send <- bytes
		}
		return

	case protocol.MsgTypeDailyChallengesGet:
		if !config.GetFeatureFlags().EnableDailyChallenges {
			m.sendError(c, protocol.ErrCodeFeatureOff, "Daily Challenges are currently disabled")
			return
		}
		challenges, err := m.gameUC.GetDailyChallenges(c.ID)
		if err != nil {
			log.Printf("Error getting daily challenges for %s: %v", c.ID, err)
			m.sendError(c, protocol.ErrCodeChallengeErr, "Failed to retrieve daily challenges")
			return
		}
		// Convert UseCase domain output to map for legacy protocol compatibility
		// or update protocol handler later. For now, manual mapping.
		// Ideally we use a method in authHandler to format this.
		// The UseCase returns []challenge.ChallengeWithProgress
		var status []map[string]interface{}
		for _, ch := range challenges {
			status = append(status, map[string]interface{}{
				"id":          ch.ID,
				"name":        ch.Title,
				"description": ch.Description,
				"reward":      ch.Reward,
				"progress":    ch.Current,
				"target":      ch.Goal,
				"claimed":     ch.IsClaimed,
				"completed":   ch.Completed,
			})
		}
		bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeDailyChallengesData, status))
		c.Send <- bytes
		return

	case protocol.MsgTypeChallengeClaim:
		var challengeID string
		if err := json.Unmarshal(baseMsg.Data, &challengeID); err != nil {
			log.Printf("ChallengeClaim unmarshal error: %v", err)
			return
		}
		err := m.gameUC.ClaimDailyChallengeReward(c.ID, challengeID)
		if err != nil {
			log.Printf("Error claiming challenge reward for %s, challenge %s: %v", c.ID, challengeID, err)
			m.sendError(c, protocol.ErrCodeClaimErr, err.Error())
			return
		}
		// Send updated challenge status and player coins
		m.authHandler.AddPlayerCoinsResponse(c)
		// Re-fetch and send challenges to update UI
		challenges, err := m.gameUC.GetDailyChallenges(c.ID)
		if err != nil {
			log.Printf("Error getting daily challenges after claim for %s: %v", c.ID, err)
			return
		}
		var status []map[string]interface{}
		for _, ch := range challenges {
			status = append(status, map[string]interface{}{
				"id":          ch.ID,
				"name":        ch.Title,
				"description": ch.Description,
				"reward":      ch.Reward,
				"progress":    ch.Current,
				"target":      ch.Goal,
				"claimed":     ch.IsClaimed,
				"completed":   ch.Completed,
			})
		}
		bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeDailyChallengesData, status))
		c.Send <- bytes
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
		m.sendError(c, protocol.ErrCodeNoRoom, "You must join a room first")
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

	r := NewPrivateRoom(roomID, data.RoomName, code, data.Password, c.ID, data.MaxPlayers, data.BootAmount, m)
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
		"createdAt": r.session.CreatedAt,
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeRoomCreated, response))
	c.Send <- bytes

	c.CurrentRoom = r
	m.SetPlayerRoom(c.ID, r)
	r.Join(c)
}

func (m *Manager) joinPrivateRoom(c *Client, data protocol.JoinPrivateRoomMessage) {
	if c.CurrentRoom != nil {
		m.sendError(c, protocol.ErrCodeAlreadyInRoom, "You are already in a room")
		return
	}

	m.mu.RLock()
	r, ok := m.Rooms[data.RoomCode]
	m.mu.RUnlock()

	if !ok {
		m.sendError(c, protocol.ErrCodeRoomNotFound, "Room not found")
		return
	}

	if !r.CheckPassword(data.Password) {
		m.sendError(c, protocol.ErrCodeInvalidPass, "Incorrect password")
		return
	}

	c.IsSpectator = data.IsSpectator
	if !c.IsSpectator && r.IsFull() {
		m.sendError(c, protocol.ErrCodeRoomFull, "Room is full")
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
	errBytes, _ := json.Marshal(protocol.NewErrorMessage(code, message))
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

// FlushEconomy flushes all buffered coin updates to the database
func (m *Manager) FlushEconomy() error {
	return m.economyUC.FlushCoins()
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

	msg := protocol.NewErrorMessage(protocol.ErrCodeKicked, reason)
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
