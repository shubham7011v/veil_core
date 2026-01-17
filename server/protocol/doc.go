// Package protocol defines the WebSocket message protocol for client-server communication.
//
// # Message Format
//
// All messages are JSON-encoded with a common structure:
//
//	{
//	  "type": "MESSAGE_TYPE",
//	  "data": { ... },
//	  "sequence": 123  // Optional: for replay protection
//	}
//
// # Message Types
//
// Authentication & Session:
//   - AUTH: Client authentication with Firebase token
//   - PING / PONG: Heartbeat keepalive
//   - UPDATE_FCM: Push notification token update
//
// Matchmaking & Rooms:
//   - JOIN_ROOM: Request to join public matchmaking
//   - CANCEL_MATCHMAKING: Leave matchmaking queue
//   - CREATE_PRIVATE_ROOM: Create a private game
//   - JOIN_PRIVATE_ROOM: Join via room code
//   - LEAVE_ROOM: Exit current room
//
// Game Actions:
//   - PLAY_CARDS: Play cards with a declared rank
//   - CHALLENGE: Challenge the last player's claim
//   - PASS: Decline to challenge
//   - CLIENT_READY: Signal UI is ready for game start
//
// # State Updates
//
// The server sends STATE_UPDATE messages containing the full game state
// or lightweight action events for performance.
//
// # Error Handling
//
// Errors are sent as ERROR messages with a code and human-readable message.
package protocol
