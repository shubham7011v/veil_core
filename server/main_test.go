package main_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"veil_server/room"
	"veil_server/protocol"
)

func TestGameFlow(t *testing.T) {
	// 1. Setup Server
	manager := room.NewManager()
	go manager.Run()
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		room.ServeWs(manager, w, r)
	}))
	defer s.Close()

	wsURL := "ws" + strings.TrimPrefix(s.URL, "http")

	// 2. Connect Clients
	connA, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil { t.Fatalf("A connect failed: %v", err) }
	defer connA.Close()

	connB, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil { t.Fatalf("B connect failed: %v", err) }
	defer connB.Close()

	// 3. Auth & Join
	sendMsg(t, connA, protocol.MsgTypeAuth, protocol.AuthMessage{Token: "A"})
	sendMsg(t, connA, "JOIN_ROOM", nil)
	sendMsg(t, connB, protocol.MsgTypeAuth, protocol.AuthMessage{Token: "B"})
	sendMsg(t, connB, "JOIN_ROOM", nil)

	// 4. Wait for Start & Identify Active Player
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
	
	if stateA["activePlayerId"] == "user_A" {
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

