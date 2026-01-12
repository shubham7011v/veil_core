package game

type Player struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	AvatarURL   string `json:"avatar_url"`
	SessionID   string `json:"sessionId"` // Temporary ID for this match (p1...p5)
	Hand        []Card `json:"-"`         // Hidden from JSON output usually, sent privately
	IsConnected bool   `json:"isConnected"`
	Wins        int    `json:"-"` // Server-only, used for rank display

	// Game state flags
	HasPassed      bool `json:"hasPassed"`      // Reset every round
	IsDisconnected bool `json:"isDisconnected"` // For grace period
}

func NewPlayer(id, name, avatar string) *Player {
	return &Player{
		ID:          id,
		Name:        name,
		AvatarURL:   avatar,
		Hand:        []Card{},
		IsConnected: true,
	}
}

func (p *Player) CardCount() int {
	return len(p.Hand)
}

func (p *Player) AddCards(cards []Card) {
	p.Hand = append(p.Hand, cards...)
}

func (p *Player) RemoveCards(cardIDs []string) []Card {
	removed := []Card{}
	newHand := []Card{}

	for _, card := range p.Hand {
		shouldRemove := false
		for _, id := range cardIDs {
			if card.ID == id {
				shouldRemove = true
				break
			}
		}

		if shouldRemove {
			removed = append(removed, card)
		} else {
			newHand = append(newHand, card)
		}
	}
	p.Hand = newHand
	return removed
}

func (p *Player) HasCards(cardIDs []string) bool {
	// CRITICAL FIX: Check for duplicate card IDs (exploit prevention)
	seen := make(map[string]bool)
	for _, id := range cardIDs {
		if seen[id] {
			return false // Duplicate detected
		}
		seen[id] = true
	}

	// Now check each unique card exists in hand
	count := 0
	for _, id := range cardIDs {
		for _, c := range p.Hand {
			if c.ID == id {
				count++
				break
			}
		}
	}
	return count == len(cardIDs)
}

func (p *Player) HandIDs() []string {
	ids := make([]string, len(p.Hand))
	for i, c := range p.Hand {
		ids[i] = c.ID
	}
	return ids
}
