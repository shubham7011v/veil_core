package game

import (
	"errors"
	"fmt"
	"math/rand"
	"time"
)

type LastMove struct {
	PlayerID     string
	DeclaredRank Rank
	ActualCards  []Card
	Timestamp    time.Time
}

type Game struct {
	Phase Phase `json:"phase"`

	Players   []*Player          `json:"-"` // Internal use
	PlayerMap map[string]*Player `json:"-"`

	// Public View for Clients
	Participants []PublicParticipant `json:"participants"`

	StartTime     int64 `json:"startTime,omitempty"`     // Unix timestamp for PhaseStarting countdown
	TurnStartTime int64 `json:"turnStartTime,omitempty"` // For turn timer

	TurnOrder []string `json:"turnOrder"`
	ActiveIdx int      `json:"activeIdx"`

	// ✅ FIX: Add CurrentPlayerID so bots can detect their turn (renamed to avoid conflict with method)
	CurrentPlayerID string `json:"activePlayerId"`

	Pile      []Card `json:"-"` // Server-only
	PileCount int    `json:"pileCount"`

	LastMove     *LastMove `json:"-"`            // Server-only (contains truth)
	DeclaredRank *Rank     `json:"declaredRank"` // Current round rank (visible)

	// Event Context for UI Animations
	LastEvent          string `json:"lastEvent,omitempty"`
	LastEventID        string `json:"lastEventId,omitempty"` // Unique ID for event de-duplication
	LastEventActorID   string `json:"lastEventActorId,omitempty"`
	LastEventCardCount int    `json:"lastEventCardCount,omitempty"`
	IsBluffSuccessful  bool   `json:"isbluffSuccessful,omitempty"`

	WinnerID string   `json:"winnerId,omitempty"`
	GameLog  []string `json:"gameLog"`
}

type PublicParticipant struct {
	ID             string `json:"id,omitempty"` // ONLY sent to the owner, others see SessionID
	SessionID      string `json:"sessionId"`
	Name           string `json:"name"`
	AvatarURL      string `json:"avatarUrl"`
	Rank           string `json:"rank"`
	IsDisconnected bool   `json:"isDisconnected"`
	UnitCount      int    `json:"cardCount"`
	IsActive       bool   `json:"isActive"` // Is it their turn?
}

func NewGame() *Game {
	return &Game{
		Phase:        PhaseLobby,
		Players:      make([]*Player, 0),
		PlayerMap:    make(map[string]*Player),
		Participants: make([]PublicParticipant, 0),
		Pile:         make([]Card, 0),
		TurnOrder:    make([]string, 0),
	}
}

func (g *Game) AddPlayer(id, name, avatar string, isBot bool) error {
	if g.Phase != PhaseLobby {
		return errors.New("cannot join active game")
	}
	if len(g.Players) >= MaxPlayers {
		return errors.New("game full")
	}
	if _, exists := g.PlayerMap[id]; exists {
		return errors.New("player already in game")
	}

	p := NewPlayer(id, name, avatar, isBot)
	g.Players = append(g.Players, p)
	g.PlayerMap[id] = p
	g.SyncParticipants() // Public view initially
	return nil
}

func (g *Game) RemovePlayer(id string) {
	p, exists := g.PlayerMap[id]
	if !exists {
		return
	}

	// ✅ FIX: maintaining deck consistency by returning cards to pile
	if len(p.Hand) > 0 {
		g.Pile = append(g.Pile, p.Hand...)
		g.PileCount = len(g.Pile)
	}

	delete(g.PlayerMap, id)

	newPlayers := make([]*Player, 0)
	for _, p := range g.Players {
		if p.ID != id {
			newPlayers = append(newPlayers, p)
		}
	}
	g.Players = newPlayers

	// CRITICAL FIX: Rebuild TurnOrder to remove disconnected player
	newTurnOrder := make([]string, 0)
	removedBeforeActive := false
	for i, pid := range g.TurnOrder {
		if pid != id {
			newTurnOrder = append(newTurnOrder, pid)
		} else if i < g.ActiveIdx {
			removedBeforeActive = true
		}
	}
	g.TurnOrder = newTurnOrder

	// Adjust ActiveIdx if player was removed before current position
	if removedBeforeActive && g.ActiveIdx > 0 {
		g.ActiveIdx--
	}

	// Ensure ActiveIdx is within bounds
	if len(g.TurnOrder) > 0 && g.ActiveIdx >= len(g.TurnOrder) {
		g.ActiveIdx = 0
	}

	g.SyncParticipants()
}

func (g *Game) Start() error {
	if len(g.Players) < MinPlayers {
		return errors.New("not enough players")
	}

	// 1. Shuffle Players for Turn Order
	perm := rand.Perm(len(g.Players))
	g.TurnOrder = make([]string, len(g.Players))
	for i, v := range perm {
		pid := g.Players[v].ID
		g.TurnOrder[i] = pid
		// Assign SessionID (p1...p5) based on turn order for consistency
		if p := g.PlayerMap[pid]; p != nil {
			p.SessionID = fmt.Sprintf("p%d", i+1)
		}
	}
	g.ActiveIdx = 0

	// 2. Deal Cards
	deck := NewDeck()
	cardsPerPlayer := len(deck) / len(g.Players)

	// Deal equally
	cursor := 0
	for _, p := range g.Players {
		end := cursor + cardsPerPlayer
		if end > len(deck) {
			end = len(deck)
		}
		p.AddCards(deck[cursor:end])
		cursor = end
	}
	// Extra cards go to first few players (or discarded? Rules say balanced usually)
	// For simplicity, ignores remainder for now or give to first player
	if cursor < len(deck) {
		g.Players[0].AddCards(deck[cursor:])
	}

	g.Phase = PhaseThinking
	g.LastEvent = "shuffling"
	g.TurnStartTime = time.Now().Unix()
	// ✅ FIX: Initialize CurrentPlayerID for bots to detect first turn
	if len(g.TurnOrder) > 0 {
		g.CurrentPlayerID = g.TurnOrder[0]
	}
	g.SyncParticipants() // Refresh with new turn order

	return nil
}

// GetParticipantsView generates a personalized view of participants for a specific owner.
// ownerID is the ID of the player this view is being generated for.
func (g *Game) GetParticipantsView(ownerID string) []PublicParticipant {
	activeID := ""
	if len(g.TurnOrder) > 0 {
		activeID = g.TurnOrder[g.ActiveIdx]
	}

	participants := make([]PublicParticipant, 0, len(g.Players))
	if len(g.TurnOrder) > 0 {
		for _, playerID := range g.TurnOrder {
			p := g.PlayerMap[playerID]
			if p == nil {
				continue
			}
			participants = append(participants, g.createPublicParticipant(p, ownerID, activeID))
		}
	} else {
		for _, p := range g.Players {
			participants = append(participants, g.createPublicParticipant(p, ownerID, activeID))
		}
	}
	return participants
}

// SyncParticipants updates the public shared view (spectator view).
func (g *Game) SyncParticipants() {
	g.Participants = g.GetParticipantsView("")
}

// createPublicParticipant creates a PublicParticipant struct, optionally revealing ID to the owner.
func (g *Game) createPublicParticipant(p *Player, ownerID, activeID string) PublicParticipant {
	var displayID string
	if p.ID == ownerID {
		displayID = p.ID
	}

	return PublicParticipant{
		ID:             displayID,
		SessionID:      p.SessionID,
		Name:           p.Name,
		AvatarURL:      p.AvatarURL,
		Rank:           CalculateRank(p.Wins),
		IsDisconnected: p.IsDisconnected,
		UnitCount:      len(p.Hand),
		IsActive:       (p.ID == activeID) && (g.Phase != PhaseFinished),
	}
}

// Helper (Duplicate of db.CalculateRank to avoid package cycle if needed, or move to common)
func CalculateRank(wins int) string {
	switch {
	case wins < 5:
		return "Novice"
	case wins < 20:
		return "Apprentice"
	case wins < 50:
		return "Adept"
	case wins < 100:
		return "Expert"
	case wins < 200:
		return "Master"
	default:
		return "Legend"
	}
}

func (g *Game) ActivePlayerID() string {
	if len(g.TurnOrder) == 0 || g.ActiveIdx < 0 || g.ActiveIdx >= len(g.TurnOrder) {
		return ""
	}
	return g.TurnOrder[g.ActiveIdx]
}

func (g *Game) AddToLog(msg string) {
	g.GameLog = append([]string{msg}, g.GameLog...)
	if len(g.GameLog) > 15 {
		g.GameLog = g.GameLog[:15]
	}
}

// IsActive returns true if the game is in an active playing phase.
// This includes thinking, challenging, and revealing phases.
func (g *Game) IsActive() bool {
	return g.Phase == PhaseThinking ||
		g.Phase == PhaseChallenging ||
		g.Phase == PhaseRevealing
}

// IsInLobbyPhase returns true if the game hasn't started yet.
// This includes both lobby and starting countdown phases.
func (g *Game) IsInLobbyPhase() bool {
	return g.Phase == PhaseLobby || g.Phase == PhaseStarting
}
