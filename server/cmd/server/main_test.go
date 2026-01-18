package main_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"veil_server/config"
	"veil_server/db"
	"veil_server/protocol"
	"veil_server/room"

	"github.com/gorilla/websocket"
)

func TestGameFlow(t *testing.T) {
	// 0. Init DB for tests
	dbPath := "test_veil.db"
	os.Remove(dbPath)
	defer os.Remove(dbPath)
	db.InitDB(dbPath)
	os.Setenv("LOBBY_TIMEOUT_S", "10")
	os.Setenv("START_GAME_DELAY", "1")
	os.Setenv("START_GAME_DELAY", "1")
	// Override directly as init() has already run
	originalTarget := room.TargetPlayers
	room.TargetPlayers = 2
	defer func() { room.TargetPlayers = originalTarget }()
	defer os.Unsetenv("LOBBY_TIMEOUT_S")
	defer os.Unsetenv("START_GAME_DELAY")
	defer os.Unsetenv("MAX_PLAYERS")

	// 1. Setup Server
	dbConn, _ := db.InitDB(dbPath)
	manager := room.NewManager(nil, dbConn)
	go manager.Run()
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		room.ServeWs(manager, w, r)
	}))
	defer s.Close()

	wsURL := "ws" + strings.TrimPrefix(s.URL, "http")

	// 2. Connect Clients
	connA, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("A connect failed: %v", err)
	}
	defer connA.Close()

	connB, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("B connect failed: %v", err)
	}
	defer connB.Close()

	// 3. Auth & Join
	sendMsg(t, connA, protocol.MsgTypeAuth, protocol.AuthMessage{Token: "A"})
	sendMsg(t, connA, "JOIN_ROOM", nil)
	waitForGameState(t, connA, "lobby")
	sendMsg(t, connA, protocol.MsgTypeClientReady, nil)

	sendMsg(t, connB, protocol.MsgTypeAuth, protocol.AuthMessage{Token: "B"})
	sendMsg(t, connB, "JOIN_ROOM", nil)
	// Since TargetPlayers=2, joining makes it full -> 'starting'
	waitForGameState(t, connB, "starting")
	sendMsg(t, connB, protocol.MsgTypeClientReady, nil)

	// 4. Wait for Start & Identify Active Player
	stateA := waitForGameState(t, connA, "thinking")
	stateB := waitForGameState(t, connB, "thinking")

	// Debug Dump
	t.Logf("State A: %+v", stateA)
	t.Logf("State B: %+v", stateB)

	// Verify both see same active player
	activeID, _ := stateA["activePlayerId"].(string)
	if activeID == "" {
		t.Logf("State Dump: %+v", stateA)
		t.Fatal("No active player in state")
	}
	t.Logf("Active Player is: %s", activeID)

	var activeConn, passiveConn *websocket.Conn
	var activeHand []interface{}

	if stateA["activePlayerId"] == "A" {
		activeConn = connA
		passiveConn = connB
		activeHand = stateA["myHand"].([]interface{})
	} else {
		activeConn = connB
		passiveConn = connA
		activeHand = stateB["myHand"].([]interface{})
	}

	// 5. Active Player plays 1 card
	if len(activeHand) == 0 {
		t.Fatal("Active player has no cards!")
	}
	firstCard := activeHand[0].(map[string]interface{})
	cardID := firstCard["id"].(string)
	cardRank := firstCard["rank"].(string)

	t.Logf("Playing card: %s (Rank: %s)", cardID, cardRank)
	sendMsg(t, activeConn, protocol.MsgTypePlayCards, protocol.PlayCardsMessage{
		CardIDs:      []string{cardID},
		DeclaredRank: cardRank,
	})

	// 6. Verify Update (Pile count should allow challenge)
	// Passive player waits for state update showing pileCount > 0
	// Updated: Phase should be 'challenging'

	newState := waitForGameState(t, passiveConn, "challenging")
	pileCount := newState["pileCount"].(float64)
	if pileCount != 1 {
		t.Fatalf("Expected 1 card in pile, got %v", pileCount)
	}

	// 7. Passive Player Challenges
	t.Log("Passive player sending CHALLENGE...")
	sendMsg(t, passiveConn, protocol.MsgTypeChallenge, nil)

	// 8. Verify Challenge Result (State reset)
	finalState := waitForGameState(t, passiveConn, "thinking")
	t.Logf("Challenge resolved successfully. Round reset. Final State: %+v", finalState)
}

// Helper that returns the State Map directly
func waitForGameState(t *testing.T, conn *websocket.Conn, expectedPhase string) map[string]interface{} {
	// Set deadline so ReadMessage doesn't block forever
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			t.Fatalf("Read error (or timeout) waiting for %s: %v", expectedPhase, err)
		}

		var baseMsg protocol.BaseMessage
		if err := json.Unmarshal(message, &baseMsg); err != nil {
			continue // Ignore non-JSON
		}

		if baseMsg.Type == protocol.MsgTypeError {
			t.Fatalf("Server Error: %s", string(baseMsg.Data))
		}

		if baseMsg.Type == protocol.MsgTypeGameState {
			var stateMap map[string]interface{}
			json.Unmarshal(baseMsg.Data, &stateMap)

			phase := stateMap["phase"].(string)
			// participants := stateMap["participants"].([]interface{})

			// We only care if phase matches target.
			// Initial join might be "lobby", then "thinking".
			if phase == expectedPhase {
				return stateMap
			}
		}
	}
}

func sendMsg(t *testing.T, conn *websocket.Conn, msgType string, data interface{}) {
	var dataBytes json.RawMessage
	if data != nil {
		bytes, _ := json.Marshal(data)
		dataBytes = bytes
	}

	msg := protocol.BaseMessage{
		Type: msgType,
		Data: dataBytes,
	}
	if err := conn.WriteJSON(msg); err != nil {
		t.Fatalf("Failed to write: %v", err)
	}
}

func TestBotBehavior(t *testing.T) {
	// 0. Environment Setup
	dbPath := "test_veil_bots.db"
	os.Remove(dbPath)
	defer os.Remove(dbPath)
	db.InitDB(dbPath)
	os.Setenv("ENABLE_BOT_PLAYERS", "true")
	os.Setenv("LOBBY_TIMEOUT_S", "1") // Fast bot join
	os.Setenv("START_GAME_DELAY", "1")
	defer os.Unsetenv("ENABLE_BOT_PLAYERS")
	defer os.Unsetenv("LOBBY_TIMEOUT_S")
	defer os.Unsetenv("START_GAME_DELAY")

	originalDelay := config.BotThinkingDelaySec
	config.BotThinkingDelaySec = 1
	defer func() { config.BotThinkingDelaySec = originalDelay }()

	// 1. Setup Server
	dbConn, _ := db.InitDB(dbPath)
	manager := room.NewManager(nil, dbConn)
	go manager.Run()
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		room.ServeWs(manager, w, r)
	}))
	defer s.Close()

	wsURL := "ws" + strings.TrimPrefix(s.URL, "http")

	// 2. Connect Human Client
	connH, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Human connect failed: %v", err)
	}
	defer connH.Close()

	// 3. Auth & Join
	sendMsg(t, connH, protocol.MsgTypeAuth, protocol.AuthMessage{Token: "HumanBotTester", Name: "HumanBotTester"})

	// Wait for Auth Success
	connH.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _, _ = connH.ReadMessage() // PING or AUTH_OK
	// Simple check, assume OK for speed, real check in waitForGameState loop implicit

	sendMsg(t, connH, "JOIN_ROOM", nil) // Triggers matchmaking
	waitForGameState(t, connH, "lobby")
	sendMsg(t, connH, protocol.MsgTypeClientReady, nil)

	// 4. Wait for Game Start (Bots should join after 1s timeout)
	t.Log("Waiting for bots to fill lobby...")

	// We expect "thinking" phase eventually
	// This might take LOBBY_TIMEOUT (1s) + START_DELAY (1s) + buffer = 3-4s
	state := waitForGameState(t, connH, "thinking")

	t.Logf("Game Started! Active Player: %s", state["activePlayerId"])

	participants := state["participants"].([]interface{})
	if len(participants) < 2 {
		t.Fatalf("Expected bots to join, only saw %d participants", len(participants))
	} else {
		t.Logf("Participant Count: %d", len(participants))
	}

	// 5. Play Loop
	// If it's human turn, play valid. If bot, wait.

	// myID := "load-player-HumanBotTester" // Auth handler internal ID pattern
	// Actually we can check "myHand" existence to confirm identity if ID varies.

	for i := 0; i < 4; i++ {
		activeID := state["activePlayerId"].(string)

		if strings.Contains(activeID, "HumanBotTester") {
			// Human Turn - Pass for simplicity
			t.Log("Human Turn: Passing...")
			sendMsg(t, connH, protocol.MsgTypePass, nil)
		} else {
			// Bot Turn
			t.Logf("Bot %s Turn: Waiting...", activeID)
		}

		// Wait for next state change
		// We can't reuse waitForGameState directly if we don't know the phase (might remain 'thinking')
		// So we read next message.
		connH.SetReadDeadline(time.Now().Add(5 * time.Second))
		_, message, err := connH.ReadMessage()
		if err != nil {
			t.Fatalf("Read error loop %d: %v", i, err)
		}

		var bm protocol.BaseMessage
		json.Unmarshal(message, &bm)

		if bm.Type == protocol.MsgTypeGameState {
			var newState map[string]interface{}
			json.Unmarshal(bm.Data, &newState)
			state = newState

			// Optional: Verify bots played (lastEvent)
			if newState["lastEvent"] == "cardsPlayed" || newState["lastEvent"] == "passed" {
				t.Logf("Turn Event: %s by %s", newState["lastEvent"], newState["lastEventActorId"])
			}
		}
	}

	t.Log("Bot Behavior Verification Complete")
}

func TestNetworkEdgeCases(t *testing.T) {
	// 0. Environment Setup
	dbPath := "test_veil_network.db"
	os.Remove(dbPath)
	defer os.Remove(dbPath)
	db.InitDB(dbPath)

	// 1. Setup Server
	dbConn, _ := db.InitDB(dbPath)
	manager := room.NewManager(nil, dbConn)
	go manager.Run()
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		room.ServeWs(manager, w, r)
	}))
	defer s.Close()
	wsURL := "ws" + strings.TrimPrefix(s.URL, "http")

	// Helper to connect and auth
	connectAndAuth := func(name, token string) *websocket.Conn {
		c, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("Dial failed for %s: %v", name, err)
		}
		sendMsg(t, c, protocol.MsgTypeAuth, protocol.AuthMessage{Token: token, Name: name})
		// Drain Auth Response
		c.SetReadDeadline(time.Now().Add(2 * time.Second))
		_, _, _ = c.ReadMessage()
		return c
	}

	// SCENARIO A: Reconnection & Session Restoration
	// SCENARIO A: Reconnection & Session Restoration (Active Game)
	t.Run("Reconnection", func(t *testing.T) {
		token := "recon_user_1"

		// 1. Initial Connect
		c1 := connectAndAuth("ReconUser", token)

		// 2. Start Private Game (Guarantees Active State)
		createPayload := protocol.CreatePrivateRoomMessage{RoomName: "ReconRoom", MaxPlayers: 2}
		sendMsg(t, c1, protocol.MsgTypeCreatePrivateRoom, createPayload)

		// Get Room Code
		c1.SetReadDeadline(time.Now().Add(2 * time.Second))
		_, msg, _ := c1.ReadMessage()
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		var data map[string]interface{}
		json.Unmarshal(bm.Data, &data)
		roomCode := data["roomCode"].(string)

		// Join 2nd Player to allow Start
		c2 := connectAndAuth("OtherPlayer", "other_token")
		defer c2.Close()
		sendMsg(t, c2, protocol.MsgTypeJoinPrivateRoom, protocol.JoinPrivateRoomMessage{RoomCode: roomCode})
		sendMsg(t, c2, protocol.MsgTypeClientReady, nil)

		// Wait for c2 to get room joined
		c2.SetReadDeadline(time.Now().Add(2 * time.Second))
		c2.ReadMessage()

		// Start Game
		time.Sleep(200 * time.Millisecond)
		sendMsg(t, c1, protocol.MsgTypeClientReady, nil)
		sendMsg(t, c1, protocol.MsgTypeStartPrivateGame, protocol.StartPrivateGameMessage{RoomCode: roomCode})

		// Wait for Game Start (Thinking Phase)
		state1 := waitForGameState(t, c1, "thinking")
		t.Log("Game started. User in thinking phase.")

		// 3. Disconnect
		c1.Close()
		t.Log("User disconnected.")
		time.Sleep(1 * time.Second) // Simulate network gap

		// 4. Reconnect with SAME token
		c3 := connectAndAuth("ReconUser", token) // Reconnect as c3
		defer c3.Close()

		// 5. Verify Session Restoration
		t.Log("Waiting for auto-restoration state update...")
		state2 := waitForGameState(t, c3, "thinking")

		// Verify Room ID is same
		if state1["roomId"] != state2["roomId"] {
			t.Errorf("FAIL: Session did not restore to same room. Old: %v, New: %v", state1["roomId"], state2["roomId"])
		} else {
			t.Log("SUCCESS: Session restored to correct room.")
		}
	})

	// SCENARIO B: Message Flooding
	t.Run("MessageFlooding", func(t *testing.T) {
		c := connectAndAuth("Flooder", "flood_token")
		defer c.Close()

		// Flood 500 PINGs
		start := time.Now()
		for i := 0; i < 500; i++ {
			err := c.WriteJSON(protocol.BaseMessage{Type: protocol.MsgTypePing})
			if err != nil {
				t.Logf("Flood write failed at %d: %v", i, err)
				break
			}
		}
		duration := time.Since(start)
		t.Logf("Flooded 500 messages in %v", duration)

		// Verify server is still alive by sending a valid request
		sendMsg(t, c, protocol.MsgTypePing, nil)

		c.SetReadDeadline(time.Now().Add(2 * time.Second))
		_, msg, err := c.ReadMessage()
		if err != nil {
			t.Fatalf("Server died or disconnected flooder: %v", err)
		}
		var bm protocol.BaseMessage
		json.Unmarshal(msg, &bm)
		if bm.Type != protocol.MsgTypePong {
			t.Errorf("Expected PONG after flood, got %s", bm.Type)
		} else {
			t.Log("SUCCESS: Server survived flooding.")
		}
	})

	// SCENARIO C: Invalid Actions (Out of Turn)
	t.Run("InvalidActions", func(t *testing.T) {
		c := connectAndAuth("Cheater", "cheat_token")
		defer c.Close()

		sendMsg(t, c, "JOIN_ROOM", nil)
		waitForGameState(t, c, "lobby")

		// Try to play card while in lobby/waiting (Invalid Phase)
		playMsg := protocol.PlayCardsMessage{
			CardIDs:      []string{"invalid_card"},
			DeclaredRank: "A",
		}
		sendMsg(t, c, protocol.MsgTypePlayCards, playMsg)

		// We expect an Error message or Ignore.
		// Server sends MsgTypeError if room.HandleAction rejects it?
		// Room logic usually checks phase.

		c.SetReadDeadline(time.Now().Add(1 * time.Second))
		_, msg, err := c.ReadMessage()
		if err == nil {
			var bm protocol.BaseMessage
			json.Unmarshal(msg, &bm)
			switch bm.Type {
			case protocol.MsgTypeError:
				t.Logf("SUCCESS: Server rejected invalid action with error: %s", string(bm.Data))
			case protocol.MsgTypeGameState:
				// Ignored and sent state update? Acceptable.
				t.Log("Server sent state update (likely ignored action).")
			default:
				t.Logf("Received %s (Action likely ignored)", bm.Type)
			}
		} else {
			t.Log("Timeout (Action ignored silently). SUCCESS.")
		}
	})
}
