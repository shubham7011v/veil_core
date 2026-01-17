// Package room manages game sessions and player connections.
//
// # Architecture Overview
//
// The room package implements the core game room management system with the following components:
//
//   - Manager: Central coordinator for all rooms and client connections
//   - Room: Individual game session container handling player lifecycle and game flow
//   - Client: WebSocket connection wrapper representing a player or bot
//   - Broadcaster: Message distribution system for efficient state synchronization
//   - Matchmaker: Automatic matchmaking and lobby management
//   - AuthHandler: Authentication and user management
//
// # Key Flows
//
//	Authentication Flow:
//	  Client connects → Manager registers → AuthHandler validates →
//	  Client authenticated → Ready for matchmaking
//
//	Matchmaking Flow:
//	  Client requests JOIN_ROOM → Matchmaker assigns to ActiveLobby →
//	  Lobby fills → Room transitions to game → Players receive state
//
//	Game Flow:
//	  Room.Run() orchestrates → Players take turns → Game validates moves →
//	  Broadcaster sends updates → Win condition checked → Room cleanup
//
// # Concurrency Model
//
// The room package is heavily concurrent with multiple goroutines coordinating through channels:
//   - Each Room runs its own goroutine (Room.Run)
//   - Manager runs a central coordination goroutine
//   - Clients have dedicated read/write goroutines
//   - All shared state is protected by sync.RWMutex
//
// # Configuration
//
// Room behavior is configured through constants in the config package:
//   - Grace periods for disconnections
//   - Turn timeouts
//   - Bot thinking delays
//   - Channel buffer sizes
package room
