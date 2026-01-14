package room

import (
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"testing"
	"time"

	"veil_server/protocol"

	"github.com/gorilla/websocket"
)

func writeJSON(c *websocket.Conn, v interface{}) error {
	b, _ := json.Marshal(v)
	return c.WriteMessage(websocket.TextMessage, b)
}

// Helper: Dial only
func connectWebSocket(t *testing.T) (*websocket.Conn, chan []byte) {
	u := url.URL{Scheme: "ws", Host: "localhost:8080", Path: "/ws"}
	dialer := websocket.DefaultDialer
	c, _, err := dialer.Dial(u.String(), nil)
	if err != nil {
		t.Fatalf("Dial error: %v", err)
	}

	msgChan := make(chan []byte, 100)
	go func() {
		defer close(msgChan)
		for {
			_, message, err := c.ReadMessage()
			if err != nil {
				return
			}
			msgChan <- message
		}
	}()
	return c, msgChan
}

// Helper: Dial + Auth
func createSimClient(t *testing.T, id string) (*websocket.Conn, chan []byte) {
	c, msgChan := connectWebSocket(t)

	// Auth
	authMsg := protocol.NewMessage(protocol.MsgTypeAuth, protocol.AuthMessage{
		Token: "mock_" + id,
		Name:  id,
	})
	writeJSON(c, authMsg)

	// Wait for AuthOk
	select {
	case msg := <-msgChan:
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type != protocol.MsgTypeAuthOk {
			t.Fatalf("Expected AUTH_OK, got %s", bm.Type)
		}
	case <-time.After(2 * time.Second):
		t.Fatalf("Auth timeout for %s", id)
	}

	return c, msgChan
}

func TestConnectionScenarios(t *testing.T) {
	// 1. Valid Connection (Implicitly tested by createSimClient, but explicit here)
	t.Run("ValidAuth", func(t *testing.T) {
		c, _ := createSimClient(t, "valid_user")
		c.Close()
	})

	// 2. Invalid Token
	t.Run("InvalidAuth", func(t *testing.T) {
		c, msgChan := connectWebSocket(t)
		defer c.Close()

		authMsg := protocol.NewMessage(protocol.MsgTypeAuth, protocol.AuthMessage{
			Token: "invalid_token_should_fail",
			Name:  "hacker",
		})
		writeJSON(c, authMsg)

		select {
		case msg := <-msgChan:
			var bm protocol.BaseMessage
			json.Unmarshal(msg, &bm)
			if bm.Type != protocol.MsgTypeError {
				t.Errorf("Expected ERROR for invalid token, got %s", bm.Type)
			}
		case <-time.After(2 * time.Second):
			t.Fatal("Timeout waiting for auth error")
		}
	})
}

func TestHeartbeat(t *testing.T) {
	c, msgChan := createSimClient(t, "heartbeat_user")
	defer c.Close()

	// Send PING
	pingMsg := protocol.BaseMessage{Type: "PING"}
	writeJSON(c, pingMsg)

	// Expect PONG
	select {
	case msg := <-msgChan:
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type != "PONG" {
			// Might get other messages (like broadcast), ignore them?
			// For now, assume quiet server, but robust tests should filter.
			if bm.Type != "PONG" {
				t.Logf("Got %s waiting for PONG, skipping...", bm.Type)
				// Retry read
				select {
				case msg2 := <-msgChan:
					json.Unmarshal(msg2, &bm)
					if bm.Type != "PONG" {
						t.Fatalf("Expected PONG, got %s", bm.Type)
					}
				case <-time.After(1 * time.Second):
					t.Fatal("Timeout waiting for PONG")
				}
			}
		}
	case <-time.After(1 * time.Second):
		t.Fatal("Timeout waiting for PONG")
	}
}

func TestMatchmakingIntegration(t *testing.T) {
	c1, m1 := createSimClient(t, "player1")
	defer c1.Close()
	c2, m2 := createSimClient(t, "player2")
	defer c2.Close()

	// Join Matchmaking
	joinMsg := protocol.NewMessage(protocol.MsgTypeJoinRoom, nil)
	writeJSON(c1, joinMsg)
	writeJSON(c2, joinMsg)

	// Verify they are in the same room
	verifyMatch := func(m chan []byte, id string) {
		timeout := time.After(5 * time.Second)
		for {
			select {
			case msg := <-m:
				var bm protocol.BaseMessage
				json.Unmarshal(msg, &bm)
				if bm.Type == protocol.MsgTypeGameState {
					var state map[string]interface{}
					json.Unmarshal(bm.Data, &state)
					participants := state["participants"].([]interface{})
					if len(participants) >= 2 {
						log.Printf("%s sees %d participants", id, len(participants))
						return
					}
				}
			case <-timeout:
				t.Fatalf("Timeout waiting for match for %s", id)
			}
		}
	}
	verifyMatch(m1, "player1")
	verifyMatch(m2, "player2")

	// Test Disconnection
	log.Printf("Simulating disconnection for player2")
	c2.Close()

	// Verify player1 sees player2 has left
	timeout := time.After(5 * time.Second)
	for {
		select {
		case msg := <-m1:
			var bm protocol.BaseMessage
			json.Unmarshal(msg, &bm)
			if bm.Type == protocol.MsgTypeGameState {
				var state map[string]interface{}
				json.Unmarshal(bm.Data, &state)
				participants := state["participants"].([]interface{})
				found := false
				for _, p := range participants {
					part := p.(map[string]interface{})
					if part["id"] == "mock_player2" {
						found = true
						break
					}
				}
				if !found {
					log.Printf("player1 confirmed player2 has left the lobby")
					goto DISCONNECT_CONFIRMED
				}
			}
		case <-timeout:
			t.Fatalf("Timeout waiting for player2 removal update for player1")
		}
	}
DISCONNECT_CONFIRMED:
	log.Printf("All integration checks passed!")
}

func TestBotSpawning(t *testing.T) {
	t.Setenv("LOBBY_TIMEOUT_S", "2")
	c1, msgChan := createSimClient(t, "solo_player")
	defer c1.Close()

	// Join Matchmaking
	joinMsg := protocol.NewMessage(protocol.MsgTypeJoinRoom, nil)
	writeJSON(c1, joinMsg)

	log.Printf("Joined matchmaking as solo player. Waiting for bots (timeout: 2s)...")

	timeout := time.After(10 * time.Second)
	for {
		select {
		case msg := <-msgChan:
			var bm protocol.BaseMessage
			json.Unmarshal(msg, &bm)
			if bm.Type == protocol.MsgTypeGameState {
				var state map[string]interface{}
				json.Unmarshal(bm.Data, &state)
				participants := state["participants"].([]interface{})
				log.Printf("Current participants: %d", len(participants))
				if len(participants) == 5 {
					log.Printf("Successfully spawned bots! Lobby is full.")
					return
				}
			}
		case <-timeout:
			t.Fatalf("Timeout waiting for bots to spawn.")
		}
	}
}

func TestDuplicateJoinRoom(t *testing.T) {
	c1, msgChan := createSimClient(t, "dup_join")
	defer c1.Close()

	readNext := func() protocol.BaseMessage {
		select {
		case msg := <-msgChan:
			var bm protocol.BaseMessage
			json.Unmarshal(msg, &bm)
			return bm
		case <-time.After(2 * time.Second):
			return protocol.BaseMessage{Type: "TIMEOUT"}
		}
	}

	// 1. Join Room
	joinMsg := protocol.NewMessage(protocol.MsgTypeJoinRoom, nil)
	writeJSON(c1, joinMsg)

	bm := readNext()
	for bm.Type != protocol.MsgTypeGameState {
		bm = readNext()
		if bm.Type == "TIMEOUT" {
			t.Fatal("Timeout waiting for initial state")
		}
	}

	// 2. Send Join Room AGAIN immediately
	writeJSON(c1, joinMsg)

	bm = readNext()
	if bm.Type == protocol.MsgTypeGameState {
		var state map[string]interface{}
		json.Unmarshal(bm.Data, &state)
		participants := state["participants"].([]interface{})
		count := 0
		for _, p := range participants {
			part := p.(map[string]interface{})
			if part["id"] == "mock_dup_join" {
				count++
			}
		}
		if count > 1 {
			t.Errorf("FAIL: Found %d instances of same player in room after duplicate JOIN_ROOM", count)
		} else {
			log.Printf("Duplicate JOIN_ROOM handled correctly (Count: %d)", count)
		}
	}
}

func TestConcurrentConnections(t *testing.T) {
	clientCount := 20 // Keep it small for quick integration test
	done := make(chan bool, clientCount)

	log.Printf("Starting concurrent load test with %d clients...", clientCount)

	for i := 0; i < clientCount; i++ {
		go func(id int) {
			clientID := fmt.Sprintf("load_user_%d", id)
			// Helper uses t.Fatalf so this might panic in goroutine effectively failing test
			//Ideally should use Errorf or channel for errors, but for simplicity:
			c, msgChan := connectWebSocket(t)
			defer c.Close()

			// Manual Auth to avoid t.Fatalf in goroutine affecting main test flow weirdly
			authMsg := protocol.NewMessage(protocol.MsgTypeAuth, protocol.AuthMessage{
				Token: "mock_" + clientID,
				Name:  clientID,
			})
			writeJSON(c, authMsg)

			select {
			case msg := <-msgChan:
				var bm protocol.BaseMessage
				json.Unmarshal(msg, &bm)
				if bm.Type != protocol.MsgTypeAuthOk {
					log.Printf("Client %d failed auth: %s", id, bm.Type)
					return
				}
			case <-time.After(5 * time.Second):
				log.Printf("Client %d auth timeout", id)
				return
			}
			done <- true
		}(i)
	}

	timeout := time.After(30 * time.Second)
	completed := 0
	for i := 0; i < clientCount; i++ {
		select {
		case <-done:
			completed++
		case <-timeout:
			t.Fatalf("Timeout waiting for clients. Completed: %d/%d", completed, clientCount)
		}
	}
	log.Printf("Successfully connected %d concurrent clients", clientCount)
}

func TestMatchmakingLifecycle(t *testing.T) {
	c1, msgChan := createSimClient(t, "cancel_player")
	defer c1.Close()

	// 1. Join
	writeJSON(c1, protocol.NewMessage(protocol.MsgTypeJoinRoom, nil))

	// Should see "GAME_STATE" (Update with self in lobby)
	select {
	case msg := <-msgChan:
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type != protocol.MsgTypeGameState {
			t.Errorf("Expected GAME_STATE after join, got %s", bm.Type)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout waiting for join confirmation")
	}

	// 2. Cancel
	writeJSON(c1, protocol.NewMessage(protocol.MsgTypeCancelMatchmaking, nil))

	// Should NOT see any more updates when another player joins
	c2, _ := createSimClient(t, "other_player")
	defer c2.Close()
	writeJSON(c2, protocol.NewMessage(protocol.MsgTypeJoinRoom, nil))

	select {
	case msg := <-msgChan: // Checking c1's channel
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		// We might get a "LEAVE" or "CANCEL" ack, but definitely not "PLAYER_JOINED" for c2
		// Currently server just stops sending updates.
		if bm.Type == protocol.MsgTypeGameState {
			// Parse to see if we are still in it?
			var state map[string]interface{}
			json.Unmarshal(bm.Data, &state)
			participants := state["participants"].([]interface{})
			for _, p := range participants {
				part := p.(map[string]interface{})
				if part["id"] == "mock_other_player" {
					t.Error("FAIL: Received update about other player after cancelling matchmaking")
					return
				}
			}
		}
	case <-time.After(1 * time.Second):
		// No news is good news
		log.Printf("Successfully validated matchmaking cancellation")
	}
}

func TestPrivateConnection(t *testing.T) {
	c1, m1 := createSimClient(t, "host_player")
	defer c1.Close()
	c2, m2 := createSimClient(t, "join_player")
	defer c2.Close()

	// 1. Create Private
	createPayload := protocol.CreatePrivateRoomMessage{
		RoomName:      "Test Room",
		MaxPlayers:    2,
		VoiceChat:     false,
		SpectatorMode: false,
	}
	writeJSON(c1, protocol.NewMessage(protocol.MsgTypeCreatePrivateRoom, createPayload))

	var roomCode string
	select {
	case msg := <-m1:
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type != protocol.MsgTypeRoomCreated {
			t.Fatalf("Expected ROOM_CREATED, got %s", bm.Type)
		}
		var data map[string]interface{}
		json.Unmarshal(bm.Data, &data)
		roomCode = data["roomCode"].(string)
		log.Printf("Created private room: %s", roomCode)
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout creating private room")
	}

	// 2. Join Private
	joinPayload := protocol.JoinPrivateRoomMessage{
		RoomCode: roomCode,
	}
	writeJSON(c2, protocol.NewMessage(protocol.MsgTypeJoinPrivateRoom, joinPayload))

	// Host should see Player Joined
	select {
	case msg := <-m1:
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type == protocol.MsgTypePlayerJoined { // Or GAME_STATE depending on impl
			log.Printf("Host saw player join")
		} else if bm.Type == protocol.MsgTypeGameState {
			log.Printf("Host received updated state")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout waiting for player join notification")
	}

	// Joiner should see Room Joined / Game State
	select {
	case msg := <-m2:
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type != protocol.MsgTypeRoomJoined && bm.Type != protocol.MsgTypeGameState {
			t.Logf("Joiner got %s", bm.Type)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout waiting for join confirmation")
	}
}

func TestGameFlow(t *testing.T) {
	c1, m1 := createSimClient(t, "game_p1")
	defer c1.Close()
	c2, m2 := createSimClient(t, "game_p2")
	defer c2.Close()

	// 1. Create & Join Private Room
	writeJSON(c1, protocol.NewMessage(protocol.MsgTypeCreatePrivateRoom, protocol.CreatePrivateRoomMessage{
		RoomName: "GameFlowRoom", MaxPlayers: 2,
	}))

	var roomCode string
	select {
	case msg := <-m1:
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type != protocol.MsgTypeRoomCreated {
			t.Fatalf("Expected ROOM_CREATED, got %s", bm.Type)
		}
		var data map[string]interface{}
		json.Unmarshal(bm.Data, &data)
		roomCode = data["roomCode"].(string)
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout creating room")
	}

	writeJSON(c2, protocol.NewMessage(protocol.MsgTypeJoinPrivateRoom, protocol.JoinPrivateRoomMessage{
		RoomCode: roomCode,
	}))

	// Drain messages until joined
	time.Sleep(500 * time.Millisecond)

	// 2. Start Game
	writeJSON(c1, protocol.NewMessage(protocol.MsgTypeStartPrivateGame, protocol.StartPrivateGameMessage{
		RoomCode: roomCode,
	}))

	log.Println("Sent START_GAME, waiting for PhaseThinking...")

	var p1Hand, p2Hand []interface{}
	var activePlayerID string

	// Helper to wait for specific phase
	waitForPhase := func(targetPhase string) {
		timeout := time.After(5 * time.Second)
		for {
			select {
			case msg := <-m1:
				var bm protocol.BaseMessage
				json.Unmarshal(msg, &bm)
				if bm.Type == protocol.MsgTypeGameState {
					var state map[string]interface{}
					json.Unmarshal(bm.Data, &state)
					if state["phase"] == targetPhase {
						activePlayerID = state["activePlayerId"].(string)
						if state["myHand"] != nil {
							p1Hand = state["myHand"].([]interface{})
						}
						return
					}
				}
			case msg := <-m2: // Keep m2 drained too so we can read its hand later
				var bm protocol.BaseMessage
				json.Unmarshal(msg, &bm)
				if bm.Type == protocol.MsgTypeGameState {
					var state map[string]interface{}
					json.Unmarshal(bm.Data, &state)
					if state["myHand"] != nil {
						p2Hand = state["myHand"].([]interface{})
					}
				}
			case <-timeout:
				t.Fatalf("Timeout waiting for phase %s", targetPhase)
			}
		}
	}

	waitForPhase("thinking")
	log.Printf("Game Started! Active Player: %s", activePlayerID)

	// 3. Play Card
	// Determine who is active
	var activeClient *websocket.Conn
	var passiveClient *websocket.Conn
	var handToPlay []interface{}
	var activeID string

	// mock_game_p1 vs mock_game_p2 (IDs from createSimClient)
	if activePlayerID == "mock_game_p1" {
		activeClient = c1
		passiveClient = c2
		handToPlay = p1Hand
		activeID = "mock_game_p1"
	} else {
		activeClient = c2
		passiveClient = c1
		handToPlay = p2Hand
		activeID = "mock_game_p2"
	}

	if len(handToPlay) == 0 {
		t.Fatal("Active player has no cards!")
	}

	card := handToPlay[0].(map[string]interface{})
	cardID := card["id"].(string)
	cardRank := card["rank"].(string)

	log.Printf("%s playing card %s (Rank: %s)", activeID, cardID, cardRank)

	playMsg := protocol.PlayCardsMessage{
		CardIDs:      []string{cardID},
		DeclaredRank: cardRank,
	}
	writeJSON(activeClient, protocol.NewMessage(protocol.MsgTypePlayCards, playMsg))

	// Verify State Update (LastEvent = cardsPlayed)
	verifiedPlay := false
	timeout := time.After(2 * time.Second)
	for !verifiedPlay {
		select {
		case msg := <-m1:
			var bm protocol.BaseMessage
			json.Unmarshal(msg, &bm)
			// Might be GAME_ACTION or GAME_STATE
			if bm.Type == protocol.MsgTypeGameAction {
				var data map[string]interface{}
				json.Unmarshal(bm.Data, &data)
				if data["action"] == "PLAY_CARDS" {
					verifiedPlay = true
				}
			} else if bm.Type == protocol.MsgTypeGameState {
				var state map[string]interface{}
				json.Unmarshal(bm.Data, &state)
				if state["lastEvent"] == "cardsPlayed" {
					verifiedPlay = true
				}
			}
		case <-timeout:
			t.Fatal("Timeout waiting for play confirmation")
		}
	}
	log.Println("Card play verified")

	// 4. Pass (by the other player)
	log.Println("Passive player passing...")
	writeJSON(passiveClient, protocol.NewMessage(protocol.MsgTypePass, nil))

	// Verify State Update (LastEvent = pileDiscarded, since 2 players, 1 pass = round end)
	verifiedPass := false
	timeout = time.After(2 * time.Second)
	for !verifiedPass {
		select {
		case msg := <-m1:
			var bm protocol.BaseMessage
			json.Unmarshal(msg, &bm)
			if bm.Type == protocol.MsgTypeGameState {
				var state map[string]interface{}
				json.Unmarshal(bm.Data, &state)
				if state["lastEvent"] == "pileDiscarded" {
					// Verify pile count is 0
					if state["pileCount"].(float64) == 0 {
						verifiedPass = true
					}
				}
			}
		case <-timeout:
			t.Fatal("Timeout waiting for pass/round-end confirmation")
		}
	}
	log.Println("Pass & Round Reset verified")
}
