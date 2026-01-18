package session

import (
	"encoding/json"
	"errors"
	"time"
	"veil_server/game"
	"veil_server/protocol"

	"github.com/pion/webrtc/v3"
)

// VoiceRelay abstracts the media server logic (WebRTC)
type VoiceRelay interface {
	HandleOffer(userID string, offer webrtc.SessionDescription) (*webrtc.SessionDescription, error)
	HandleICE(userID string, candidate webrtc.ICECandidateInit) error
	SetSpeaker(speakerID string)
}

// Session represents the domain state of a game room, decoupled from networking.
type Session struct {
	ID       string
	Game     *game.Game
	Settings Settings
	Voice    *game.VoiceState
	WebRTC   VoiceRelay

	// State Tracking
	DisconnectTimes map[string]time.Time
	ReadyClients    map[string]bool

	// Timing State (managed by infrastructure ticks, but state stored here)
	CreatedAt    int64
	LastFullSync time.Time
}

type Settings struct {
	Name       string
	Code       string
	Password   string
	IsPrivate  bool
	HostID     string
	MaxPlayers int
	BootAmount float64
}

func NewSession(id string, settings Settings, relay VoiceRelay) *Session {
	return &Session{
		ID:              id,
		Game:            game.NewGame(),
		Settings:        settings,
		Voice:           game.NewVoiceState(),
		WebRTC:          relay,
		DisconnectTimes: make(map[string]time.Time),
		ReadyClients:    make(map[string]bool),
		CreatedAt:       time.Now().Unix(),
		LastFullSync:    time.Now(),
	}
}

// Result of processing an action, instructing the infrastructure layer what to do.
type ActionResult struct {
	BroadcastState bool
	BroadcastEvent *BroadcastEvent // Helper struct for specific events
	Error          error
	ClientResponse any // Direct response to sender
}

type BroadcastEvent struct {
	Type    string
	Payload interface{}
}

// Logic Methods extracted from Room

func (s *Session) AddPlayer(id, name, avatar string, isBot bool) error {
	return s.Game.AddPlayer(id, name, avatar, isBot)
}

func (s *Session) RemovePlayer(id string) {
	s.Game.RemovePlayer(id)
	delete(s.DisconnectTimes, id)
	delete(s.ReadyClients, id)
}

func (s *Session) IsFull() bool {
	// Logic: Count players in game + potential joiners?
	// This mirrors Room.IsFull but logic might differ if we strictly use Game.Players
	// Room.IsFull allowed for "connected but not in game" clients.
	// For Domain Session, we only care about Game Participants.
	return len(s.Game.Players) >= s.Settings.MaxPlayers
}

func (s *Session) IsActive() bool {
	return s.Game.IsActive()
}

func (s *Session) MarkDisconnected(playerID string) {
	if s.IsActive() {
		s.DisconnectTimes[playerID] = time.Now()
		if p := s.Game.PlayerMap[playerID]; p != nil {
			p.IsDisconnected = true
		}
	} else {
		// In active game, mark. In lobby, remove.
		s.RemovePlayer(playerID)
	}
}

// HandleAction processes a game protocol message and returns the result/events.
func (s *Session) HandleAction(playerID string, msg protocol.BaseMessage) ActionResult {
	var err error

	switch msg.Type {
	case protocol.MsgTypePlayCards:
		var payload protocol.PlayCardsMessage
		if unmarshalErr := json.Unmarshal(msg.Data, &payload); unmarshalErr != nil {
			return ActionResult{Error: unmarshalErr}
		}

		rank := game.Rank(payload.DeclaredRank)
		if !game.IsValidRank(rank) {
			return ActionResult{Error: errors.New("invalid rank")}
		}

		err = s.Game.PlayCards(playerID, payload.CardIDs, rank)
		if err == nil {
			// Construct hybrid event payload
			p := s.Game.PlayerMap[playerID]
			eventPayload := map[string]interface{}{
				"playerId":           playerID,
				"count":              len(payload.CardIDs),
				"declaredRank":       payload.DeclaredRank,
				"newPileCount":       s.Game.PileCount,
				"nextPlayerId":       s.Game.ActivePlayerID(),
				"playerNewCardCount": len(p.Hand),
				"turnStartTime":      s.Game.TurnStartTime,
			}

			return ActionResult{
				BroadcastState: true, // Full sync is safe default
				BroadcastEvent: &BroadcastEvent{
					Type:    "PLAY_CARDS",
					Payload: eventPayload,
				},
			}
		}

	case protocol.MsgTypePass:
		err = s.Game.Pass(playerID)
		if err == nil {
			eventPayload := map[string]interface{}{
				"playerId":      playerID,
				"nextPlayerId":  s.Game.ActivePlayerID(),
				"turnStartTime": s.Game.TurnStartTime,
			}
			// Special case: Pile discarded
			if s.Game.LastEvent == "pileDiscarded" {
				return ActionResult{BroadcastState: true} // Full sync for reset
			}
			return ActionResult{
				BroadcastState: true,
				BroadcastEvent: &BroadcastEvent{
					Type:    "PASS",
					Payload: eventPayload,
				},
			}
		}

	case protocol.MsgTypeChallenge:
		_, err = s.Game.Challenge(playerID)
		if err == nil {
			// Challenge initiated - leads to Revealing phase
			return ActionResult{BroadcastState: true}
		}

	case protocol.MsgTypeChat:
		var payload protocol.ChatMessage
		if err := json.Unmarshal(msg.Data, &payload); err == nil {
			p := s.Game.PlayerMap[playerID]
			name := "Player " + playerID
			if p != nil {
				name = p.Name
			}

			eventPayload := map[string]interface{}{
				"senderId":   playerID,
				"senderName": name,
				"message":    payload.Message,
				"time":       time.Now().Unix(),
			}
			return ActionResult{
				BroadcastEvent: &BroadcastEvent{
					Type:    protocol.MsgTypeChat,
					Payload: eventPayload,
				},
			}
		}

	case protocol.MsgTypeEmoji:
		var payload protocol.EmojiMessage
		if err := json.Unmarshal(msg.Data, &payload); err == nil {
			eventPayload := map[string]interface{}{
				"senderId": playerID,
				"emojiId":  payload.EmojiID,
			}
			return ActionResult{
				BroadcastEvent: &BroadcastEvent{
					Type:    protocol.MsgTypeEmoji,
					Payload: eventPayload,
				},
			}
		}

	case protocol.MsgTypeTyping:
		var payload protocol.TypingMessage
		if err := json.Unmarshal(msg.Data, &payload); err == nil {
			eventPayload := map[string]interface{}{
				"senderId": playerID,
				"isTyping": payload.IsTyping,
			}
			return ActionResult{
				BroadcastEvent: &BroadcastEvent{
					Type:    protocol.MsgTypeTyping,
					Payload: eventPayload,
				},
			}
		}

	case protocol.MsgTypeLeaveRoom:
		s.RemovePlayer(playerID)
		return ActionResult{BroadcastState: true}

	case protocol.MsgTypeStartGame, protocol.MsgTypeStartPrivateGame:
		if s.Game.Phase == game.PhaseLobby {
			if s.Settings.IsPrivate && playerID != s.Settings.HostID {
				return ActionResult{Error: errors.New("only host can start the game")}
			}
			err = s.Game.Start()
			if err == nil {
				return ActionResult{BroadcastState: true}
			}
		}
	}

	if err != nil {
		return ActionResult{Error: err}
	}

	// ✅ ANTI-CHEAT: Final consistency check after any successful action that modifies state
	if s.IsActive() {
		if vErr := s.Game.VerifyDeckConsistency(); vErr != nil {
			// This signals a critical internal state mismatch
			return ActionResult{Error: vErr}
		}
	}

	return ActionResult{}
}
