package room

import (
	"log"
	"encoding/json"
	"veil_server/protocol"
)

// Manager keeps track of all clients and rooms
type Manager struct {
	Clients    map[*Client]bool
	Register   chan *Client
	Unregister chan *Client
	
	Rooms      map[string]*Room
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
		// TODO: verify firebase format
		// Mock logic:
		var authData protocol.AuthMessage
		json.Unmarshal(baseMsg.Data, &authData)
		c.ID = "user_" + authData.Token // Mock ID
		
		response := protocol.NewMessage(protocol.MsgTypeAuthOk, protocol.AuthOkMessage{
			PlayerID: c.ID,
		})
		bytes, _ := json.Marshal(response)
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
			Code: "NO_ROOM",
			Message: "You must join a room first",
		}))
		c.Send <- errBytes
	}
}
