package room

// RoomInterface defines the interface for room operations
// This allows for dependency injection and easier testing with mock implementations
type RoomInterface interface {
	// Client Management
	Join(client *Client)
	Leave(client *Client)
	Stop()
	HandleAction(action GameAction)

	// State Queries
	IsFull() bool
	IsPrivate() bool
	GetInfo() map[string]interface{}
	GetGamePhase() string
	GetClientCount() int
	GetPlayerIDs() []string
	CheckPassword(pw string) bool

	// Broadcasting
	ForceBroadcastState()

	// For internal use by Manager
	Run()
	GetUnicastActionChannel(client *Client) chan<- GameAction
}

// RoomManagerInterface defines the interface for the central room manager
// This manages all rooms and clients
type RoomManagerInterface interface {
	Run()
	HandleMessage(c *Client, message []byte)
	AttemptJoinActiveLobby(c *Client)

	// Admin operations
	GetActiveRooms() []ActiveRoomInfo
	BroadcastSystemMessage(message string)
	KickUser(userID string, reason string)
}

// ClientInterface defines the interface for a connected client
type ClientInterface interface {
	GetID() string
	GetDisplayName() string
	IsAuthenticated() bool
	GetRoom() *Room
}

// Note: The existing Room and Manager structs already implement these interfaces
// We don't need wrappers since all methods are already defined.

// For compile-time interface compliance checks:
var (
	_ RoomInterface        = (*Room)(nil)
	_ RoomManagerInterface = (*Manager)(nil)
)
