package game

import (
	"errors"
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

	Players    []*Player `json:"-"` // Internal use
	PlayerMap  map[string]*Player `json:"-"`
	
	// Public View for Clients
	Participants []PublicParticipant `json:"participants"`

	TurnOrder []string `json:"turnOrder"`
	ActiveIdx int      `json:"activeIdx"`

	Pile       []Card    `json:"-"` // Server-only
	PileCount  int       `json:"pileCount"`
	
	LastMove     *LastMove `json:"-"` // Server-only (contains truth)
	DeclaredRank *Rank     `json:"declaredRank"` // Current round rank (visible)
	
	WinnerID string `json:"winnerId,omitempty"`
}

type PublicParticipant struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	CardCount int    `json:"cardCount"`
	IsActive  bool   `json:"isActive"` // Is it their turn?
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

func (g *Game) AddPlayer(id, name string) error {
	if g.Phase != PhaseLobby {
		return errors.New("cannot join active game")
	}
	if len(g.Players) >= MaxPlayers {
		return errors.New("game full")
	}
	if _, exists := g.PlayerMap[id]; exists {
		return errors.New("player already in game")
	}

	p := NewPlayer(id, name)
	g.Players = append(g.Players, p)
	g.PlayerMap[id] = p
	return nil
}

func (g *Game) Start() error {
	if len(g.Players) < MinPlayers {
		return errors.New("not enough players")
	}

	// 1. Shuffle Players for Turn Order
	rand.Seed(time.Now().UnixNano())
	perm := rand.Perm(len(g.Players))
	g.TurnOrder = make([]string, len(g.Players))
	for i, v := range perm {
		g.TurnOrder[i] = g.Players[v].ID
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
	g.SyncParticipants()
	
	return nil
}

// SyncParticipants updates the public view struct
func (g *Game) SyncParticipants() {
	g.Participants = make([]PublicParticipant, len(g.Players))
	activeID := ""
	if len(g.TurnOrder) > 0 {
		activeID = g.TurnOrder[g.ActiveIdx]
	}

	// Maintain order based on TurnOrder if game started, else join order
	// Actually, let's just use g.Players list order for display, 
	// but mark IsActive based on ID match.
	
	for i, p := range g.Players {
		g.Participants[i] = PublicParticipant{
			ID:        p.ID,
			Name:      p.Name,
			CardCount: len(p.Hand),
			IsActive:  (p.ID == activeID) && (g.Phase != PhaseFinished),
		}
	}
}

func (g *Game) ActivePlayerID() string {
	if len(g.TurnOrder) == 0 {
		return ""
	}
	return g.TurnOrder[g.ActiveIdx]
}
