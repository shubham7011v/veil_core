package game

import (
	"errors"
	"fmt"
	"log"
	"time"
)

// PlayCards attempts to play cards for the current user
func (g *Game) PlayCards(playerID string, cardIDs []string, declaredRank Rank) error {
	if g.Phase != PhaseThinking {
		return errors.New("not thinking phase")
	}
	if g.ActivePlayerID() != playerID {
		return errors.New("not your turn")
	}
	if len(cardIDs) == 0 || len(cardIDs) > 4 {
		return errors.New("invalid card count (1-4)")
	}

	p := g.PlayerMap[playerID]
	if !p.HasCards(cardIDs) {
		return errors.New("you don't possess these cards")
	}

	// Logic Check: If round rank is set, must match (server authorizes this rule)
	// But in bluff, you can LIE. So you just check against declaredRank.
	// HOWEVER, providing a different registered *rank* than the round's rank
	// is usually illegal unless it's the start of a round.
	if g.DeclaredRank != nil && *g.DeclaredRank != declaredRank {
		return errors.New("must play current round rank")
	}

	// Move cards from Hand -> Pile
	removed := p.RemoveCards(cardIDs)
	g.Pile = append(g.Pile, removed...)
	g.PileCount = len(g.Pile)

	// Update Last Move
	g.LastMove = &LastMove{
		PlayerID:     playerID,
		DeclaredRank: declaredRank,
		ActualCards:  removed,
		Timestamp:    time.Now(),
	}

	// Set round rank if new round
	if g.DeclaredRank == nil {
		g.DeclaredRank = &declaredRank
	}

	g.ResetPassFlags() // New move breaks pass cycle
	g.AdvanceTurn()
	g.Phase = PhaseChallenging // Now others can challenge

	// UI Context
	g.LastEvent = "cardsPlayed"
	g.LastEventID = fmt.Sprintf("%d", time.Now().UnixNano())
	g.LastEventActorID = playerID
	g.LastEventCardCount = len(cardIDs)

	g.AddToLog(fmt.Sprintf("%s claimed %d %s(s)", g.PlayerMap[playerID].Name, len(cardIDs), declaredRank))

	g.SyncParticipants("")

	// CHECK WIN CONDITION: Player reaches 0 cards
	if len(p.Hand) == 0 {
		g.Phase = PhaseFinished
		g.WinnerID = playerID
		g.LastEvent = "gameOver"
		g.AddToLog(fmt.Sprintf("%s won the game!", g.PlayerMap[playerID].Name))
		log.Printf("Game Over: %s won by reaching 0 cards", playerID)
	}

	return nil
}

func (g *Game) Challenge(challengerID string) (bool, error) {
	if g.Phase != PhaseChallenging {
		return false, errors.New("cannot challenge now")
	}
	if g.ActivePlayerID() != challengerID {
		return false, errors.New("not your turn to challenge")
	}
	if g.LastMove == nil {
		return false, errors.New("nothing to challenge")
	}

	declared := g.LastMove.DeclaredRank
	actual := g.LastMove.ActualCards

	isBluff := false
	for _, c := range actual {
		if c.Rank != declared {
			isBluff = true
			break
		}
	}

	// Prepare for Reveal Phase
	g.Phase = PhaseRevealing
	g.LastEvent = "bluffCalled"
	g.LastEventID = fmt.Sprintf("%d", time.Now().UnixNano())
	g.LastEventActorID = challengerID
	g.IsBluffSuccessful = isBluff
	// Note: We don't resolve yet. ResolveChallenge() must be called later.

	return isBluff, nil
}

// ResolveChallenge finalizes the result after the reveal animation delay
func (g *Game) ResolveChallenge(challengerID string) string {
	if g.Phase != PhaseRevealing || g.LastMove == nil {
		return ""
	}

	blufferID := g.LastMove.PlayerID
	loserID := ""
	winnerID := ""

	if g.IsBluffSuccessful {
		// Bluffer eats pile
		loserID = blufferID
		winnerID = challengerID
	} else {
		// Challenger eats pile
		loserID = challengerID
		winnerID = blufferID
	}

	pileCount := g.PileCount
	g.GivePileTo(loserID)
	g.ResetRound()
	g.SyncParticipants("")

	g.SetTurnMessages(winnerID)

	result := "BLUFF CAUGHT!"
	if !g.IsBluffSuccessful {
		result = "FALSE ALARM!"
	}
	g.AddToLog(fmt.Sprintf("%s on %s by %s. %s picks up %d cards.", result, g.PlayerMap[blufferID].Name, g.PlayerMap[challengerID].Name, g.PlayerMap[loserID].Name, pileCount))

	return loserID + " lost the challenge!"
}

func (g *Game) Pass(playerID string) error {
	if g.ActivePlayerID() != playerID {
		return errors.New("not your turn")
	}
	// Can pass in Thinking (start of round?) -> Allowed to pass turn to start?
	// Can pass in Challenging (decline to challenge) -> Yes.

	p := g.PlayerMap[playerID]
	p.HasPassed = true

	// Check if ALL passed
	if g.CheckAllPassed() {
		// Round ends, cards discarded
		g.ResetRound()

		// UI Context
		g.LastEvent = "pileDiscarded"
		g.LastEventID = fmt.Sprintf("%d", time.Now().UnixNano())
		g.LastEventActorID = "" // Neutral

		g.AddToLog("Everyone passed. Pile discarded.")

		if g.LastMove != nil {
			g.SetTurnMessages(g.LastMove.PlayerID)
		}
	} else {
		// UI Context
		g.LastEvent = "passed"
		g.LastEventID = fmt.Sprintf("%d", time.Now().UnixNano())
		g.LastEventActorID = playerID

		g.AddToLog(fmt.Sprintf("%s passed", g.PlayerMap[playerID].Name))

		g.AdvanceTurn()
	}

	g.SyncParticipants("")
	return nil
}

// -- Helpers --

func (g *Game) AdvanceTurn() {
	if len(g.TurnOrder) == 0 {
		return
	}

	// Advance to next player, skipping disconnected ones
	maxAttempts := len(g.TurnOrder) // Prevent infinite loop
	for i := 0; i < maxAttempts; i++ {
		g.ActiveIdx = (g.ActiveIdx + 1) % len(g.TurnOrder)
		playerID := g.TurnOrder[g.ActiveIdx]
		player := g.PlayerMap[playerID]

		// Found a connected player
		if player != nil && !player.IsDisconnected {
			g.TurnStartTime = time.Now().Unix()
			return
		}
	}

	// All players disconnected - this shouldn't happen in practice
	// but we set timer anyway to prevent nil pointer issues
	g.TurnStartTime = time.Now().Unix()
}

func (g *Game) SetTurnMessages(playerID string) {
	for i, id := range g.TurnOrder {
		if id == playerID {
			g.ActiveIdx = i
			break
		}
	}
}

func (g *Game) GivePileTo(playerID string) {
	p := g.PlayerMap[playerID]
	p.AddCards(g.Pile)
	g.Pile = make([]Card, 0)
	g.PileCount = 0
}

func (g *Game) ResetRound() {
	g.Pile = make([]Card, 0) // Discard if passed out, or cached before GivePileTo
	g.PileCount = 0
	g.DeclaredRank = nil
	g.LastMove = nil
	g.ResetPassFlags()
	g.Phase = PhaseThinking
}

func (g *Game) ResetPassFlags() {
	for _, p := range g.Players {
		p.HasPassed = false
	}
}

func (g *Game) CheckAllPassed() bool {
	// If Everyone EXCEPT the last mover has passed...
	// In 2 player: A plays, B passes -> All passed? Yes.
	passCount := 0
	for _, p := range g.Players {
		if p.HasPassed {
			passCount++
		}
	}
	// If N-1 players passed (all except the one who played last)
	return passCount >= (len(g.Players) - 1)
}
