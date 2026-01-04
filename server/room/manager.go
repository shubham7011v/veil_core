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
}

func NewManager() *Manager {
	return &Manager{
		Clients:    make(map[*Client]bool),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
		Rooms:      make(map[string]*Room),
	}
}

func (m *Manager) Run() {
	for {
		select {
		case client := <-m.Register:
			m.Clients[client] = true
			log.Println("New Connection Registered")

		case client := <-m.Unregister:
			if _, ok := m.Clients[client]; ok {
				delete(m.Clients, client)
				if client.CurrentRoom != nil {
					client.CurrentRoom.Unregister <- client
				}
				close(client.Send)
				log.Println("Connection Unregistered")
			}

			// We could add a global broadcast channel if needed
		}
	}
}

// HandleMessage routes incoming messages from clients
func (m *Manager) HandleMessage(c *Client, message []byte) {
	// 1. Parse ONLY the type first
	var baseMsg protocol.BaseMessage
	if err := json.Unmarshal(message, &baseMsg); err != nil {
		log.Printf("Invalid JSON: %v", err)
		return
	}

	log.Printf("Msg Type: %s from Client %v", baseMsg.Type, c.ID)

	// 2. Global Handlers (Auth, Join Room)
	switch baseMsg.Type {
	case protocol.MsgTypeAuth:
		var authData protocol.AuthMessage
		if err := json.Unmarshal(baseMsg.Data, &authData); err != nil {
			log.Printf("Auth unmarshal error: %v", err)
			return
		}

		// TEMP: Use token as UserID until we have real Firebase verification
		// Adding nano suffix ONLY if it's "mock_token" to keep useful real logins consistent
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
			// Proceed anyway but with empty stats? Or fail?
			// Let's proceed with empty stats for resilience
			stats = &db.UserStats{UserID: c.ID, Name: "Unknown", Rank: "Novice"}
		}

		// Return AUTH_OK with Stats
		// We need to update protocol package to support stats field first?
		// Or just use a map for flexible JSON
		responseMap := map[string]interface{}{
			"playerId":   c.ID,
			"stats":      stats,
			"serverTime": time.Now(),
		}

		msg := protocol.NewMessage(protocol.MsgTypeAuthOk, responseMap)
		bytes, _ := json.Marshal(msg)
		c.Send <- bytes

		return // Handled

	case "JOIN_ROOM": // Custom internal message for now
		// Logic to find/create room and add client
		// Mock:
		roomID := "demo"
		room, ok := m.Rooms[roomID]
		if !ok {
			room = NewRoom(roomID)
			m.Rooms[roomID] = room
			go room.Run()
		}
		c.CurrentRoom = room
		room.Register <- c
		return
	}

	// 3. Room-scoped Handlers (Play, Pass, etc)
	if c.CurrentRoom != nil {
		// NEW: Send to action channel for game processing
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
