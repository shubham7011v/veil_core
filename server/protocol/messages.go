package protocol

import "encoding/json"

// Message Type Constants
const (
	// Client -> Server
	MsgTypeAuth      = "AUTH"
	MsgTypePlayCards = "PLAY_CARDS"
	MsgTypePass      = "PASS"
	MsgTypeChallenge = "CHALLENGE"
	MsgTypeStartGame = "START_GAME"

	// Server -> Client
	MsgTypeAuthOk          = "AUTH_OK"
	MsgTypeAuthFail        = "AUTH_FAIL"
	MsgTypeGameState       = "GAME_STATE"
	MsgTypePlayerJoined    = "PLAYER_JOINED"
	MsgTypeCardsPlayed     = "CARDS_PLAYED"
	MsgTypeTurnPassed      = "TURN_PASSED"
	MsgTypeChallengeResult = "CHALLENGE_RESULT"
	MsgTypeGameOver        = "GAME_OVER"
	MsgTypeError           = "ERROR"

	// Leaderboard
	MsgTypeLeaderboardGet  = "LEADERBOARD_GET"
	MsgTypeLeaderboardData = "LEADERBOARD_DATA"

	// Social / Friends
	MsgTypeFriendRequest = "FRIEND_REQUEST"
	MsgTypeFriendAccept  = "FRIEND_ACCEPT"
	MsgTypeFriendList    = "FRIEND_LIST"
)

// BaseMessage structure for all WebSocket messages
type BaseMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data,omitempty"` // For specialized decoding
}

// -- Client Messages --

type AuthMessage struct {
	Token string `json:"token"`
}

type PlayCardsMessage struct {
	CardIDs      []string `json:"cardIds"`
	DeclaredRank string   `json:"declaredRank"`
}

// -- Server Messages --

type AuthOkMessage struct {
	PlayerID string `json:"playerId"`
}

type ErrorMessage struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Helper to wrap payload in a standard message map
func NewMessage(msgType string, payload any) map[string]any {
	return map[string]any{
		"type": msgType,
		"data": payload,
	}
}
