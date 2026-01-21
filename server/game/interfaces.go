package game

// GameEngine defines the interface for game logic operations
// This allows for dependency injection and easier testing with mock implementations
type GameEngine interface {
	// Game Actions
	PlayCards(playerID string, cardIDs []string, declaredRank Rank) error
	Challenge(challengerID string) (bool, error)
	ResolveChallenge(challengerID string) string
	Pass(playerID string) error

	// Game State
	GetState() *Game
	ActivePlayerID() string
	GetPlayerHand(playerID string) []Card

	// Player Management
	AddPlayer(id, name, avatar string) error
	RemovePlayer(id string)
	Start() error

	// Sync & Helpers
	SyncParticipants()
	GetParticipantsView(ownerID string) []PublicParticipant
	AddToLog(msg string)
}

// DeckManager defines the interface for deck operations
type DeckManager interface {
	CreateDeck() []Card
	ShuffleCard(cards []Card)
}

// GameEngineImpl is a wrapper for the Game struct to implement GameEngine interface
// Since Game already has all the methods, we just need to add the missing ones
type GameEngineImpl struct {
	*Game
}

// NewGameEngine creates a new game engine instance
func NewGameEngine() GameEngine {
	return &GameEngineImpl{
		Game: NewGame(),
	}
}

// GetState returns the underlying game state
func (g *GameEngineImpl) GetState() *Game {
	return g.Game
}

// GetPlayerHand returns a player's hand
func (g *GameEngineImpl) GetPlayerHand(playerID string) []Card {
	if p, ok := g.PlayerMap[playerID]; ok {
		return p.Hand
	}
	return []Card{}
}

// GetParticipantsView returns a personalized view of participants
func (g *GameEngineImpl) GetParticipantsView(ownerID string) []PublicParticipant {
	return g.Game.GetParticipantsView(ownerID)
}
