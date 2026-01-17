package game

import (
	"testing"
)

func TestGameTurnCyclingWithDisconnects(t *testing.T) {
	g := NewGame()

	// Add 3 players
	g.AddPlayer("p1", "Player 1", "")
	g.AddPlayer("p2", "Player 2", "")
	g.AddPlayer("p3", "Player 3", "")

	err := g.Start()
	if err != nil {
		t.Fatalf("Failed to start game: %v", err)
	}

	// Check initial turn
	activeID := g.ActivePlayerID()
	if activeID == "" {
		t.Fatal("Expected active player ID")
	}

	// Simulate p2 disconnecting
	// Find which one is p2 in TurnOrder
	p2Idx := -1
	for i, id := range g.TurnOrder {
		if id == "p2" {
			p2Idx = i
		}
	}

	g.PlayerMap["p2"].IsDisconnected = true

	// Set active index to the player BEFORE p2
	g.ActiveIdx = (p2Idx - 1 + len(g.TurnOrder)) % len(g.TurnOrder)

	// Advance turn - should skip p2 and go to the next one
	g.AdvanceTurn()

	newActiveID := g.ActivePlayerID()
	if newActiveID == "p2" {
		t.Errorf("Turn advanced to disconnected player p2")
	}

	// Simulate everyone else disconnecting
	g.PlayerMap["p1"].IsDisconnected = true
	g.PlayerMap["p3"].IsDisconnected = true

	g.AdvanceTurn() // Should not hang due to maxAttempts
}

func TestGameStartRules(t *testing.T) {
	g := NewGame()

	// Test minimum players
	err := g.Start()
	if err == nil {
		t.Error("Expected error when starting game with 0 players")
	}

	g.AddPlayer("p1", "p1", "")
	g.AddPlayer("p2", "p2", "")

	err = g.Start()
	if err != nil {
		t.Fatalf("Failed to start game with 2 players: %v", err)
	}

	if g.Phase != PhaseThinking {
		t.Errorf("Expected PhaseThinking, got %s", g.Phase)
	}

	if len(g.TurnOrder) != 2 {
		t.Errorf("Expected TurnOrder size 2, got %d", len(g.TurnOrder))
	}

	// Check card distribution
	totalCards := 0
	for _, p := range g.Players {
		totalCards += len(p.Hand)
	}
	if totalCards != 52 {
		t.Errorf("Expected 52 cards total, got %d", totalCards)
	}
}

func TestBluffLogic(t *testing.T) {
	g := NewGame()
	g.AddPlayer("p1", "p1", "")
	g.AddPlayer("p2", "p2", "")
	g.Start()

	// Force p1's turn
	g.SetTurnMessages("p1")
	p1 := g.PlayerMap["p1"]

	// Give p1 specific cards
	p1.Hand = []Card{
		{ID: "c1", Suit: Spades, Rank: RankTwo},
		{ID: "c2", Suit: Hearts, Rank: RankThree},
	}

	// Play a bluff (Two labeled as Three)
	err := g.PlayCards("p1", []string{"c1"}, RankThree)
	if err != nil {
		t.Fatalf("Failed to play cards: %v", err)
	}

	if g.Phase != PhaseChallenging {
		t.Errorf("Expected PhaseChallenging, got %s", g.Phase)
	}

	// Challenger (p2) calls bluff
	isBluff, err := g.Challenge("p2")
	if err != nil {
		t.Fatalf("Challenge failed: %v", err)
	}

	if !isBluff {
		t.Error("Expected isBluff to be true")
	}

	// Resolve
	loser := g.ResolveChallenge("p2")
	if loser == "" {
		t.Error("Expected a loser ID in result")
	}

	if len(g.PlayerMap["p1"].Hand) != 2 {
		t.Errorf("Expected p1 to have 2 cards after losing bluff, got %d", len(g.PlayerMap["p1"].Hand))
	}
}

func TestRemovePlayerDeckConsistency(t *testing.T) {
	g := NewGame()
	g.AddPlayer("p1", "p1", "")
	g.AddPlayer("p2", "p2", "")
	g.AddPlayer("p3", "p3", "")

	if err := g.Start(); err != nil {
		t.Fatalf("Failed to start game: %v", err)
	}

	// Initial check
	if err := g.VerifyDeckConsistency(); err != nil {
		t.Fatalf("Initial consistency check failed: %v", err)
	}

	// Remove p2 (who has cards)
	p2HandSize := len(g.PlayerMap["p2"].Hand)
	if p2HandSize == 0 {
		t.Fatal("p2 should have cards dealt")
	}

	g.RemovePlayer("p2")

	// Check Pile
	if g.PileCount != p2HandSize {
		t.Errorf("Expected pile count %d, got %d", p2HandSize, g.PileCount)
	}

	// Final consistency check
	if err := g.VerifyDeckConsistency(); err != nil {
		t.Errorf("Post-removal consistency check failed: %v", err)
	}

	// Verify p2 is gone
	if _, exists := g.PlayerMap["p2"]; exists {
		t.Error("p2 should be removed from map")
	}
}
