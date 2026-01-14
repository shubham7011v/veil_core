package room

import (
	"fmt"
	"os"
	"sync"
	"testing"
	"time"
	"veil_server/db"
	"veil_server/game"
)

func TestLoadMatchmaking(t *testing.T) {
	// Speed up the test
	game.StartGameDelayS = 1

	if testing.Short() {
		t.Skip("skipping load test in short mode")
	}

	// Initialize temporary database for test
	dbPath := "test_load.db"
	db.InitDB(dbPath)
	defer os.Remove(dbPath)

	m := NewManager(nil)
	go m.Run()

	numClients := 20
	var wg sync.WaitGroup
	wg.Add(numClients)

	clients := make([]*Client, numClients)

	// 1. Concurrent Registration
	for i := 0; i < numClients; i++ {
		go func(id int) {
			defer wg.Done()
			c := &Client{
				ID:   fmt.Sprintf("load-player-%d", id),
				Name: fmt.Sprintf("Player %d", id),
				Hub:  m,
				Send: make(chan []byte, 256), // Large buffer for load
			}
			clients[id] = c
			m.Register <- c
		}(i)
	}
	wg.Wait()

	// 2. Concurrent Matchmaking Join
	for i := 0; i < numClients; i++ {
		go func(id int) {
			m.AttemptJoinActiveLobby(clients[id])
		}(i)
	}

	// 3. Monitor Results
	timeout := time.After(30 * time.Second)
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	done := false
	for !done {
		select {
		case <-timeout:
			m.mu.RLock()
			t.Errorf("Load test timed out. Rooms: %d, LobbyCount: %d", len(m.Rooms), m.ActiveLobbyCount)
			m.mu.RUnlock()
			done = true
		case <-ticker.C:
			m.mu.RLock()
			roomCount := len(m.Rooms)
			lobbyCount := m.ActiveLobbyCount
			playerInRooms := 0
			for _, r := range m.Rooms {
				// Don't count the active lobby itself if it hasn't started
				if r.GetGamePhase() != "lobby" {
					playerInRooms += r.GetClientCount()
				}
			}
			m.mu.RUnlock()

			fmt.Printf("Status: TotalRooms=%d, LobbyCount=%d, PlayersInActiveGames=%d\n", roomCount, lobbyCount, playerInRooms)

			if playerInRooms >= numClients {
				fmt.Printf("SUCCESS: All %d players matched into %d rooms\n", numClients, roomCount)
				done = true
			}
		}
	}

	// Cleanup
	m.Shutdown()
}
