package room

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"strings"
	"time"

	"veil_server/protocol"
)

// AuthHandler manages authentication and user account operations
// Extracted from Manager to improve modularity and single-responsibility
type AuthHandler struct {
	manager *Manager
}

// NewAuthHandler creates a new authentication handler
func NewAuthHandler(m *Manager) *AuthHandler {
	return &AuthHandler{manager: m}
}

// HandleAuth processes authentication messages and verifies Firebase tokens
func (ah *AuthHandler) HandleAuth(c *Client, authData protocol.AuthMessage) {
	// Call UseCase
	u, err := ah.manager.authUC.Authenticate(context.Background(), authData.Token, authData.Name, authData.AvatarURL)
	if err != nil {
		if err.Error() == protocol.ErrCodeAuthTimeout {
			ah.manager.sendError(c, protocol.ErrCodeAuthTimeout, "Authentication service temporarily unavailable")
		} else {
			log.Printf("Auth Failed: %v", err)
			ah.manager.sendError(c, protocol.ErrCodeAuthFailed, "Authentication failed")
		}
		return
	}

	// Update Client Identity
	c.ID = u.ID
	c.Name = u.Name
	c.AvatarURL = u.AvatarURL

	// Map to legacy stats format for protocol compatibility
	stats := map[string]interface{}{
		"userId":      u.ID,
		"name":        u.Name,
		"avatarUrl":   u.AvatarURL,
		"rank":        u.Rank,
		"coins":       u.Coins,
		"gamesPlayed": u.GamesPlayed,
		"wins":        u.Wins,
		"losses":      u.Losses,
	}
	ah.SendAuthOk(c, stats)

	// Session Restoration: Check if player belongs to an active game
	if r := ah.manager.FindRoomByPlayerID(c.ID); r != nil {
		log.Printf("AUTH: Auto-restoring session for %s in room %s", c.ID, r.ID)
		c.CurrentRoom = r
		r.Join(c)
	}
}

// HandleUpdateName processes name change requests
func (ah *AuthHandler) HandleUpdateName(c *Client, data []byte) {
	var payload protocol.UpdateNameMessage
	if err := json.Unmarshal(data, &payload); err != nil {
		return
	}

	u, err := ah.manager.authUC.UpdateName(c.ID, payload.Name)
	if err != nil {
		// Log or error?
		return
	}

	stats := map[string]interface{}{
		"userId":      u.ID,
		"name":        u.Name,
		"avatarUrl":   u.AvatarURL,
		"rank":        u.Rank,
		"coins":       u.Coins,
		"gamesPlayed": u.GamesPlayed,
		"wins":        u.Wins,
		"losses":      u.Losses,
	}
	ah.SendAuthOk(c, stats)
}

// HandleRefillCoins processes coin refill requests for low-balance users
func (ah *AuthHandler) HandleRefillCoins(c *Client) {
	u, err := ah.manager.authUC.RefillCoins(c.ID)
	if err != nil {
		ah.manager.sendError(c, protocol.ErrCodeRefillDenied, "You have enough coins or error occurred")
		return
	}

	stats := map[string]interface{}{
		"userId":      u.ID,
		"name":        u.Name,
		"avatarUrl":   u.AvatarURL,
		"rank":        u.Rank,
		"coins":       u.Coins,
		"gamesPlayed": u.GamesPlayed,
		"wins":        u.Wins,
		"losses":      u.Losses,
	}
	ah.SendAuthOk(c, stats)
}

// HandleChallengeClaim: Logic Moved to Manager
// This method is kept as a legacy stub if needed, but Manager handles MsgTypeChallengeClaim now.
// We can remove it or deprecated it. Removing to avoid confusion since logic is in Manager now.

// HandleDeleteAccount processes account deletion requests
func (ah *AuthHandler) HandleDeleteAccount(c *Client) {
	log.Printf("User %s requested account deletion", c.ID)
	if err := ah.manager.authUC.DeleteAccount(c.ID); err != nil {
		ah.manager.sendError(c, protocol.ErrCodeDeleteFailed, "Could not delete account data")
		return
	}
	ah.manager.sendError(c, protocol.ErrCodeAccountDeleted, "Your account has been permanently deleted")
	if c.CurrentRoom != nil {
		c.CurrentRoom.Leave(c)
	}
}

// AddFriendListResponse fetches and sends friend list
func (ah *AuthHandler) AddFriendListResponse(c *Client) {
	friends, err := ah.manager.socialUC.GetFriends(c.ID)
	if err != nil {
		return
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeFriendList, friends))
	c.Send <- bytes
}

// AddPlayerCoinsResponse sends updated user stats (coins) to the client
func (ah *AuthHandler) AddPlayerCoinsResponse(c *Client) {
	// Re-fetch user stats via AuthUC
	u, err := ah.manager.authUC.GetUser(c.ID)
	if err != nil {
		return
	}

	stats := map[string]interface{}{
		"userId":      u.ID,
		"name":        u.Name,
		"avatarUrl":   u.AvatarURL,
		"rank":        u.Rank,
		"coins":       u.Coins,
		"gamesPlayed": u.GamesPlayed,
		"wins":        u.Wins,
		"losses":      u.Losses,
	}
	ah.SendAuthOk(c, stats)
}

// SendAuthOk sends successful authentication response with user stats
func (ah *AuthHandler) SendAuthOk(c *Client, stats interface{}) {
	isAdmin := false
	if adminUIDsEnv := os.Getenv("ADMIN_UIDS"); adminUIDsEnv != "" {
		for _, uid := range strings.Split(adminUIDsEnv, ",") {
			if strings.TrimSpace(uid) == strings.TrimSpace(c.ID) {
				isAdmin = true
				break
			}
		}
	}

	msg := protocol.NewMessage(protocol.MsgTypeAuthOk, map[string]interface{}{
		"playerId":   c.ID,
		"stats":      stats,
		"serverTime": time.Now(),
		"isAdmin":    isAdmin,
	})
	bytes, _ := json.Marshal(msg)
	c.Send <- bytes
}
