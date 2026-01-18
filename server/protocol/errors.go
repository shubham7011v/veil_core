package protocol

// Error Codes
const (
	ErrCodeAuthFailed     = "AUTH_FAILED"
	ErrCodeAuthTimeout    = "AUTH_TIMEOUT"
	ErrCodeGameError      = "GAME_ERROR"
	ErrCodeInvalidMsg     = "INVALID_MESSAGE"
	ErrCodeRateLimited    = "RATE_LIMITED"
	ErrCodeRefillDenied   = "REFILL_DENIED"
	ErrCodeDeleteFailed   = "DELETE_FAILED"
	ErrCodeRoomNotFound   = "ROOM_NOT_FOUND"
	ErrCodeAccessDenied   = "ACCESS_DENIED"
	ErrCodeUserBanned     = "USER_BANNED"
	ErrCodeAccountDeleted = "ACCOUNT_DELETED"
	ErrCodeNoRoom         = "NO_ROOM"
	ErrCodeAlreadyInRoom  = "ALREADY_IN_ROOM"
	ErrCodeInvalidPass    = "INVALID_PASSWORD"
	ErrCodeRoomFull       = "ROOM_FULL"
	ErrCodeFeatureOff     = "FEATURE_DISABLED"
	ErrCodeChallengeErr   = "CHALLENGE_ERROR"
	ErrCodeClaimErr       = "CLAIM_ERROR"
	ErrCodeLowBalance     = "INSUFFICIENT_FUNDS"
	ErrCodeKicked         = "KICKED"
)

// NewErrorMessage wraps a code and message into a standard error response
func NewErrorMessage(code, message string) map[string]any {
	return NewMessage(MsgTypeError, ErrorMessage{
		Code:    code,
		Message: message,
	})
}
