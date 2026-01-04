package room

import (
	"encoding/json"
	"fmt"
	"log"
	"time"
	"veil_server/db"
	"veil_server/protocol"
)

// Manager keeps track of all clients and rooms
type Manager struct {
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
					client.CurrentRoom.Unregister <- client
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
		room.Register <- c
	}

	// Wait briefly for registers then start
	go func() {
		time.Sleep(500 * time.Millisecond)
		startMsg := protocol.BaseMessage{Type: protocol.MsgTypeStartGame}
		// Send start triggering via first client
		room.Actions <- GameAction{Client: clients[0], Message: startMsg}
	}()
}

// HandleMessage routes incoming messages from clients
func (m *Manager) HandleMessage(c *Client, message []byte) {
	// 1. Parse ONLY the type first
	var baseMsg protocol.BaseMessage
	if err := json.Unmarshal(message, &baseMsg); err != nil {
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
		// Simplified mock detection
		if len(userID) > 20 && userID[:5] == "mock_" {
			userID = fmt.Sprintf("%s_%d", userID, time.Now().UnixNano()%10000)
		}

		c.ID = userID

		// Get Data from SQLite
		stats, err := db.GetOrCreateUser(c.ID, "Player "+c.ID[:4])
		if err != nil {
			log.Printf("DB Error: %v", err)
			stats = &db.UserStats{UserID: c.ID, Name: "Unknown", Rank: "Novice"}
		}

		responseMap := map[string]interface{}{
			"playerId":   c.ID,
			"stats":      stats,
			"serverTime": time.Now(),
		}

		msg := protocol.NewMessage(protocol.MsgTypeAuthOk, responseMap)
		bytes, _ := json.Marshal(msg)
		c.Send <- bytes

		return // Handled

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
		addFriendListResponse(c)
		return

	case protocol.MsgTypeFriendList:
		addFriendListResponse(c)
		return

	case "JOIN_ROOM":
		// Add to Matchmaking Queue
		// (Ignore payload for now, assume auto-match)
		if c.CurrentRoom == nil {
			m.Queue.Add(c)
		} else {
			// Already in room? Re-send state?
			c.CurrentRoom.BroadcastState()
		}
		return
	}

	// 3. Room-scoped Handlers (Play, Pass, etc)
	if c.CurrentRoom != nil {
		c.CurrentRoom.Actions <- GameAction{
			Client:  c,
			Message: baseMsg,
		}
	} else {
		// Error: Not in room
		errBytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeError, protocol.ErrorMessage{
			Code:    "NO_ROOM",
			Message: "You must join a room first",
		}))
		c.Send <- errBytes
	}
}

func addFriendListResponse(c *Client) {
	friends, err := db.GetFriends(c.ID)
	if err != nil {
		log.Printf("Friend list error: %v", err)
		return
	}

	msg := protocol.NewMessage(protocol.MsgTypeFriendList, friends)
	bytes, _ := json.Marshal(msg)
	c.Send <- bytes
}
