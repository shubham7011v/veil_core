package protocol

import "encoding/json"

// Message Type Constants
const (
	// Client -> Server
	MsgTypeAuth          = "AUTH"
	MsgTypePlayCards     = "PLAY_CARDS"
	MsgTypePass          = "PASS"
	MsgTypeChallenge     = "CHALLENGE"
	MsgTypeStartGame     = "START_GAME"
	MsgTypeUpdateName    = "UPDATE_NAME"
	MsgTypeUpdateAvatar  = "UPDATE_AVATAR"
	MsgTypeRefillCoins   = "REFILL_COINS"
	MsgTypeDeleteAccount = "DELETE_ACCOUNT"

	// Private Room (Client -> Server)
	MsgTypeCreatePrivateRoom = "CREATE_PRIVATE_ROOM"
	MsgTypeJoinPrivateRoom   = "JOIN_PRIVATE_ROOM"
	MsgTypeStartPrivateGame  = "START_PRIVATE_GAME"
	MsgTypeLeaveRoom         = "LEAVE_ROOM"

	// Server -> Client
	MsgTypeAuthOk          = "AUTH_OK"
	MsgTypeAuthFail        = "AUTH_FAIL"
	MsgTypeGameState       = "GAME_STATE"
	MsgTypePlayerJoined    = "PLAYER_JOINED"
	MsgTypeCardsPlayed     = "CARDS_PLAYED"
	MsgTypeTurnPassed      = "TURN_PASSED"
	MsgTypeChallengeResult = "CHALLENGE_RESULT"
	MsgTypeGameOver        = "GAME_OVER"
	MsgTypeSystemAlert     = "SYSTEM_ALERT"
	MsgTypeError           = "ERROR"

	// Private Room (Server -> Client)
	MsgTypeRoomCreated = "ROOM_CREATED"
	MsgTypeRoomJoined  = "ROOM_JOINED"
	MsgTypeRoomUpdate  = "ROOM_UPDATE"

	// Leaderboard
	MsgTypeLeaderboardGet  = "LEADERBOARD_GET"
	MsgTypeLeaderboardData = "LEADERBOARD_DATA"

	// Social / Friends
	MsgTypeFriendRequest = "FRIEND_REQUEST"
	MsgTypeFriendAccept  = "FRIEND_ACCEPT"
	MsgTypeFriendList    = "FRIEND_LIST"

	// Voice
	MsgTypeVoiceHandRaise = "VOICE_RAISE_HAND"
	MsgTypeVoiceState     = "VOICE_STATE"
	MsgTypeVoiceSDP       = "VOICE_SDP"
	MsgTypeVoiceICE       = "VOICE_ICE"

	// Daily Challenges
	MsgTypeChallengesGet    = "CHALLENGES_GET"
	MsgTypeChallengesData   = "CHALLENGES_DATA"
	MsgTypeChallengeClaim   = "CHALLENGE_CLAIM"
	MsgTypeChallengeClaimOk = "CHALLENGE_CLAIM_OK"
	// Social
	MsgTypeChat   = "CHAT"
	MsgTypeEmoji  = "EMOJI"
	MsgTypeTyping = "TYPING"
)

// BaseMessage structure for all WebSocket messages
type BaseMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data,omitempty"` // For specialized decoding
}

// -- Client Messages --

type AuthMessage struct {
	Token     string `json:"token"`
	Name      string `json:"name,omitempty"`
	AvatarURL string `json:"avatar_url,omitempty"`
}

type UpdateAvatarMessage struct {
	AvatarURL string `json:"avatar_url"`
}

type UpdateNameMessage struct {
	Name string `json:"name"`
}

type PlayCardsMessage struct {
	CardIDs      []string `json:"cardIds"`
	DeclaredRank string   `json:"declaredRank"`
}

type ChatMessage struct {
	Message string `json:"message"`
}

type EmojiMessage struct {
	EmojiID string `json:"emojiId"`
}

type TypingMessage struct {
	IsTyping bool `json:"isTyping"`
}

type CreatePrivateRoomMessage struct {
	RoomName      string  `json:"roomName"`
	Password      string  `json:"password,omitempty"`
	MaxPlayers    int     `json:"maxPlayers"`
	BootAmount    float64 `json:"bootAmount"`
	VoiceChat     bool    `json:"voiceChat"`
	SpectatorMode bool    `json:"spectatorMode"`
}

type JoinPrivateRoomMessage struct {
	RoomCode    string `json:"roomCode"`
	Password    string `json:"password,omitempty"`
	IsSpectator bool   `json:"isSpectator"`
}

type StartPrivateGameMessage struct {
	RoomCode string `json:"roomCode"`
}

type LeaveRoomMessage struct {
	RoomCode string `json:"roomCode"`
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
