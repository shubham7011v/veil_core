package room

import (
	"encoding/json"
	"os"
	"testing"
	"time"
	"veil_server/db"
	"veil_server/protocol"
)

func TestPlayerIndexing(t *testing.T) {
	dbConn, err := db.InitDB(":memory:")
	if err != nil {
		t.Fatalf("Failed to init DB: %v", err)
	}
	m := NewManager(nil, dbConn)

	// Mock room and client
	playerID := "test-player-1"
	r := NewRoom("room-1", m)
	m.Rooms["room-1"] = r

	// Test SetPlayerRoom
	m.SetPlayerRoom(playerID, r)

	found := m.FindRoomByPlayerID(playerID)
	if found == nil || found != r {
		t.Errorf("Expected to find room via PlayerRooms map, got %v", found)
	}

	// Test RemovePlayerRoom
	m.RemovePlayerRoom(playerID)
	found = m.FindRoomByPlayerID(playerID)
	if found != nil {
		t.Errorf("Expected nil after removing player room, got %v", found)
	}
}

func TestMatchmakingCancellation(t *testing.T) {
	// Initialize temporary database for test
	dbPath := "test_room_cancel.db"
	os.Remove(dbPath)
	dbConn, err := db.InitDB(dbPath)
	if err != nil {
		t.Fatalf("Failed to init DB: %v", err)
	}
	defer os.Remove(dbPath)

	m := NewManager(nil, dbConn)
	go m.Run() // Start manager loop

	client := &Client{
		ID:   "player-1",
		Hub:  m,
		Send: make(chan []byte, 32),
	}

	// 1. Join Lobby
	m.Register <- client
	time.Sleep(50 * time.Millisecond) // Wait for registration

	m.AttemptJoinActiveLobby(client)
	time.Sleep(50 * time.Millisecond)

	if m.ActiveLobbyCount != 1 {
		t.Errorf("Expected LobbyCount 1, got %d", m.ActiveLobbyCount)
	}

	// 2. Cancel Matchmaking
	msg, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeCancelMatchmaking, nil))
	m.HandleMessage(client, msg)
	time.Sleep(50 * time.Millisecond)

	if m.ActiveLobbyCount != 0 {
		t.Errorf("Expected LobbyCount 0 after cancellation, got %d", m.ActiveLobbyCount)
	}

	if client.CurrentRoom != nil {
		t.Errorf("Expected CurrentRoom to be nil after cancellation")
	}
}

func TestRegistrationBuffer(t *testing.T) {
	dbConn, err := db.InitDB(":memory:")
	if err != nil {
		t.Fatalf("Failed to init DB: %v", err)
	}
	m := NewManager(nil, dbConn)
	// Manager.Register is buffered at 1024
	// We should be able to send many registrations without blocking even if Manager is not running

	for i := 0; i < 500; i++ {
		c := &Client{ID: "p", Send: make(chan []byte, 1)}
		select {
		case m.Register <- c:
			// OK
		case <-time.After(10 * time.Millisecond):
			t.Fatalf("Register channel blocked at iteration %d", i)
		}
	}
}
