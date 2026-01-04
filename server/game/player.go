package game

type Player struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Hand        []Card `json:"-"` // Hidden from JSON output usually, sent privately
	IsConnected bool   `json:"isConnected"`
	
	// Game state flags
	HasPassed bool `json:"hasPassed"` // Reset every round
}

func NewPlayer(id, name string) *Player {
	return &Player{
		ID:   id,
		Name: name,
		Hand: []Card{},
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
