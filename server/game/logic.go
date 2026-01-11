package game

import (
	"errors"
	"fmt"
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
	g.LastEventActorID = playerID
	g.LastEventCardCount = len(cardIDs)

	g.AddToLog(fmt.Sprintf("%s claimed %d %s(s)", g.PlayerMap[playerID].Name, len(cardIDs), declaredRank))

	g.SyncParticipants()

	// Check for immediate win (0 cards) - NO, must survive challenge first?
	// Rules say: "Winner: First player to reach 0 cards".
	// Usually safe if they survive the circle, but let's check count.
	// We'll verify win condition after challenge window or on next turn start.

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
	g.SyncParticipants()

	g.ResetRound()
	g.SyncParticipants()

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
		g.LastEventActorID = "" // Neutral

		g.AddToLog("Everyone passed. Pile discarded.")

		if g.LastMove != nil {
			g.SetTurnMessages(g.LastMove.PlayerID)
		}
	} else {
		// UI Context
		g.LastEvent = "passed"
		g.LastEventActorID = playerID

		g.AddToLog(fmt.Sprintf("%s passed", g.PlayerMap[playerID].Name))

		g.AdvanceTurn()
	}

	g.SyncParticipants()
	return nil
}

// -- Helpers --

func (g *Game) AdvanceTurn() {
	g.ActiveIdx = (g.ActiveIdx + 1) % len(g.TurnOrder)

	// If the active player is finished (0 cards), do they get skipped?
	// For "First to 0 wins", game ends immediately.
	// If "Last Man Standing", skip. Assumed First to 0 for now.
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
