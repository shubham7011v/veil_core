package game

import (
	"errors"
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
	g.SyncParticipants()
	
	// Check for immediate win (0 cards) - NO, must survive challenge first?
	// Rules say: "Winner: First player to reach 0 cards". 
	// Usually safe if they survive the circle, but let's check count.
	// We'll verify win condition after challenge window or on next turn start.
	
	return nil
}

func (g *Game) Challenge(challengerID string) (string, error) {
	// Returns (Message, Error)
	if g.Phase != PhaseChallenging {
		// Actually, standard rule is next player challenges.
		// If strict turn-based: Challenger must be ActivePlayerID
		return "", errors.New("cannot challenge now")
	}
	if g.ActivePlayerID() != challengerID {
		return "", errors.New("not your turn to challenge")
	}
	if g.LastMove == nil {
		return "", errors.New("nothing to challenge")
	}

	blufferID := g.LastMove.PlayerID
	declared := g.LastMove.DeclaredRank
	actual := g.LastMove.ActualCards
	
	isBluff := false
	for _, c := range actual {
		if c.Rank != declared {
			isBluff = true
			break
		}
	}

	loserID := ""
	winnerID := ""

	if isBluff {
		// Challenger wins, Bluffer eats pile
		loserID = blufferID
		winnerID = challengerID
	} else {
		// Challenger loses, Challenger eats pile
		loserID = challengerID
		winnerID = blufferID
	}
	
	g.GivePileTo(loserID)
	g.ResetRound()
	g.SyncParticipants()
	
	// Set turn to Winner (who was right/innocent)
	g.SetTurnMessages(winnerID)

	return loserID + " lost the challenge!", nil
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
		// Turn remains with the current active player (who was last to make move usually?)
		// Actually if A played, B passed, C passed... A starts new round.
		// logic: The player BEFORE the first passer (the one who played).
		// Since we advanced turn, identifying "Original Mover" requires state tracking.
		// Simplified: If all pass, the player who LAST PLAYED (g.LastMove.PlayerID) starts.
		if g.LastMove != nil {
			g.SetTurnMessages(g.LastMove.PlayerID)
		}
	} else {
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
