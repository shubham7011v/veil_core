package game

import (
	"testing"
)

func TestGameTurnCyclingWithDisconnects(t *testing.T) {
	g := NewGame()

	// Add 3 players
	g.AddPlayer("p1", "Player 1", "", false)
	g.AddPlayer("p2", "Player 2", "", false)
	g.AddPlayer("p3", "Player 3", "", false)

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

	g.AddPlayer("p1", "p1", "", false)
	g.AddPlayer("p2", "p2", "", false)

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
	g.AddPlayer("p1", "p1", "", false)
	g.AddPlayer("p2", "p2", "", false)
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
	g.AddPlayer("p1", "p1", "", false)
	g.AddPlayer("p2", "p2", "", false)
	g.AddPlayer("p3", "p3", "", false)

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

func TestChallengeResolution(t *testing.T) {
	g := NewGame()
	g.AddPlayer("p1", "Player 1", "", false)
	g.AddPlayer("p2", "Player 2", "", false)
	g.Start()

	// Test successful bluff detection
	t.Run("Bluff detected correctly", func(t *testing.T) {
		g.SetTurnMessages("p1")
		p1 := g.PlayerMap["p1"]
		p1.Hand = []Card{
			{ID: "c1", Suit: Spades, Rank: RankTwo},
		}

		// Play bluff: Two as Three
		g.PlayCards("p1", []string{"c1"}, RankThree)
		isBluff, _ := g.Challenge("p2")

		if !isBluff {
			t.Error("Expected bluff to be detected")
		}
	})

	// Test honest play
	t.Run("Honest play not marked as bluff", func(t *testing.T) {
		g2 := NewGame()
		g2.AddPlayer("p1", "P1", "", false)
		g2.AddPlayer("p2", "P2", "", false)
		g2.Start()
		g2.SetTurnMessages("p1")

		p1 := g2.PlayerMap["p1"]
		p1.Hand = []Card{
			{ID: "c1", Suit: Spades, Rank: RankThree},
		}

		// Play honest: Three as Three
		g2.PlayCards("p1", []string{"c1"}, RankThree)
		isBluff, _ := g2.Challenge("p2")

		if isBluff {
			t.Error("Expected honest play not to be bluff")
		}
	})
}

func TestPassMechanics(t *testing.T) {
	g := NewGame()
	g.AddPlayer("p1", "Player 1", "", false)
	g.AddPlayer("p2", "Player 2", "", false)
	g.AddPlayer("p3", "Player 3", "", false)
	g.Start()

	// Set up game state: p1 plays cards
	g.SetTurnMessages("p1")
	p1 := g.PlayerMap["p1"]
	p1.Hand = []Card{{ID: "c1", Suit: Spades, Rank: RankTwo}}
	g.PlayCards("p1", []string{"c1"}, RankTwo)

	initialPileCount := g.PileCount

	// p2 passes
	err := g.Pass("p2")
	if err != nil {
		t.Fatalf("Pass failed: %v", err)
	}

	// p3 passes - should trigger pile discard (2 consecutive passes)
	err = g.Pass("p3")
	if err != nil {
		t.Fatalf("Second pass failed: %v", err)
	}

	// Pile should be discarded after enough passes
	if g.PileCount != 0 {
		t.Errorf("Expected pile to be discarded after consecutive passes, got pile count %d", g.PileCount)
	}

	// Test pass count tracking
	if g.PileCount == 0 && initialPileCount > 0 {
		// Pass was successful and pile was cleared
		if g.Phase != PhaseThinking {
			t.Errorf("Expected phase to be thinking after pile clear, got %s", g.Phase)
		}
	}
}

func TestWinCondition(t *testing.T) {
	t.Run("Player wins when hand is empty", func(t *testing.T) {
		g := NewGame()
		g.AddPlayer("p1", "Winner", "", false)
		g.AddPlayer("p2", "Loser", "", false)
		g.Start()

		// Give p1 only one card
		p1 := g.PlayerMap["p1"]
		p1.Hand = []Card{{ID: "c1", Suit: Spades, Rank: RankAce}}

		// Set p1 as active
		g.SetTurnMessages("p1")

		// Play last card
		err := g.PlayCards("p1", []string{"c1"}, RankAce)
		if err != nil {
			t.Fatalf("Failed to play winning card: %v", err)
		}

		// Check if p1 has zero cards
		if len(p1.Hand) != 0 {
			t.Errorf("Expected p1 to have 0 cards, got %d", len(p1.Hand))
		}
	})
}

func TestCardValidation(t *testing.T) {
	t.Run("Invalid card ID should fail", func(t *testing.T) {
		g := NewGame()
		g.AddPlayer("p1", "P1", "", false)
		g.AddPlayer("p2", "P2", "", false)
		g.Start()

		g.SetTurnMessages("p1")

		// Try to play card that doesn't exist in hand
		err := g.PlayCards("p1", []string{"nonexistent_card"}, RankTwo)
		if err == nil {
			t.Error("Expected error when playing invalid card ID")
		}
	})

	t.Run("Cannot play on other player's turn", func(t *testing.T) {
		g := NewGame()
		g.AddPlayer("p1", "P1", "", false)
		g.AddPlayer("p2", "P2", "", false)
		g.Start()

		// Set p1 as active
		g.SetTurnMessages("p1")

		// Try to play as p2 (not active)
		p2 := g.PlayerMap["p2"]
		if len(p2.Hand) > 0 {
			err := g.PlayCards("p2", []string{p2.Hand[0].ID}, RankTwo)
			if err == nil {
				t.Error("Expected error when playing out of turn")
			}
		}
	})
}

func TestMultiCardPlay(t *testing.T) {
	g := NewGame()
	g.AddPlayer("p1", "Player 1", "", false)
	g.AddPlayer("p2", "Player 2", "", false)
	g.Start()

	g.SetTurnMessages("p1")
	p1 := g.PlayerMap["p1"]

	// Give p1 multiple cards of same rank
	p1.Hand = []Card{
		{ID: "c1", Suit: Spades, Rank: RankTwo},
		{ID: "c2", Suit: Hearts, Rank: RankTwo},
		{ID: "c3", Suit: Clubs, Rank: RankTwo},
	}

	// Play all three cards
	err := g.PlayCards("p1", []string{"c1", "c2", "c3"}, RankTwo)
	if err != nil {
		t.Fatalf("Failed to play multiple cards: %v", err)
	}

	// Pile should have 3 cards
	if g.PileCount != 3 {
		t.Errorf("Expected pile count 3, got %d", g.PileCount)
	}

	// Player should have 0 cards left
	if len(p1.Hand) != 0 {
		t.Errorf("Expected p1 to have 0 cards, got %d", len(p1.Hand))
	}
}
