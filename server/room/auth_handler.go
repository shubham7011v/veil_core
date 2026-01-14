package room

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"strings"
	"time"

	"veil_server/config"
	"veil_server/db"
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
	tokenString := authData.Token
	userName := authData.Name
	userID := tokenString
	firebaseName := userName
	firebaseAvatar := authData.AvatarURL

	if ah.manager.AuthClient != nil && !strings.HasPrefix(tokenString, "mock_") {
		// ✅ FIX: Add timeout to Firebase verification
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		token, err := ah.manager.AuthClient.VerifyIDToken(ctx, tokenString)
		if err == nil {
			userID = token.UID
			if firebaseName == "" && token.Claims["name"] != nil {
				firebaseName = token.Claims["name"].(string)
			}
			if firebaseAvatar == "" && token.Claims["picture"] != nil {
				firebaseAvatar = token.Claims["picture"].(string)
			}
		} else {
			// Check if it was a timeout
			if err == context.DeadlineExceeded {
				log.Printf("Token verification timeout for client: %v", err)
				ah.manager.sendError(c, "AUTH_TIMEOUT", "Authentication service temporarily unavailable")
			} else {
				log.Printf("Token verify failed: %v", err)
				ah.manager.sendError(c, "AUTH_FAILED", "Invalid authentication token")
			}
			return
		}
	}

	if firebaseName == "" {
		nameID := userID
		if len(nameID) > 4 {
			nameID = nameID[:4]
		}
		firebaseName = "Player " + nameID
	}

	c.ID = userID
	c.Name = firebaseName
	c.AvatarURL = firebaseAvatar

	stats, err := db.GetOrCreateUser(c.ID, firebaseName)
	if err == nil {
		if firebaseAvatar != "" {
			db.UpdateUserAvatar(c.ID, firebaseAvatar)
			stats.AvatarURL = firebaseAvatar
		}
	} else {
		stats = &db.UserStats{UserID: c.ID, Name: "Unknown", Rank: "Novice", Coins: 1000}
	}
	ah.SendAuthOk(c, stats)

	// ✅ Session Restoration: Check if player belongs to an active game
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
	if err := db.UpdateUserName(c.ID, payload.Name); err != nil {
		return
	}
	stats, _ := db.GetOrCreateUser(c.ID, payload.Name)
	ah.SendAuthOk(c, stats)
}

// HandleRefillCoins processes coin refill requests for low-balance users
func (ah *AuthHandler) HandleRefillCoins(c *Client) {
	stats, _ := db.GetOrCreateUser(c.ID, "")
	if stats.Coins < 100 {
		topUp := 1000 - stats.Coins
		if err := db.UpdateUserCoins(c.ID, topUp); err == nil {
			stats.Coins = 1000
			ah.SendAuthOk(c, stats)
		}
	} else {
		ah.manager.sendError(c, "REFILL_DENIED", "You have enough coins!")
	}
}

// HandleChallengeClaim processes checking and rewarding daily challenges
func (ah *AuthHandler) HandleChallengeClaim(c *Client, data []byte) {
	if !config.GetFeatureFlags().EnableDailyChallenges {
		ah.manager.sendError(c, "FEATURE_DISABLED", "Daily Challenges are currently disabled")
		return
	}
	var challengeID string
	json.Unmarshal(data, &challengeID)
	reward, err := db.ClaimChallengeReward(c.ID, challengeID)
	if err != nil {
		ah.manager.sendError(c, "CLAIM_FAILED", err.Error())
		return
	}

	response := map[string]interface{}{
		"challengeId": challengeID,
		"reward":      reward,
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeChallengeClaimOk, response))
	c.Send <- bytes

	stats, err := db.GetOrCreateUser(c.ID, "")
	if err == nil {
		ah.SendAuthOk(c, stats)
	}
}

// HandleDeleteAccount processes account deletion requests
func (ah *AuthHandler) HandleDeleteAccount(c *Client) {
	log.Printf("User %s requested account deletion", c.ID)
	if err := db.DeleteUser(c.ID); err != nil {
		ah.manager.sendError(c, "DELETE_FAILED", "Could not delete account data")
		return
	}
	ah.manager.sendError(c, "ACCOUNT_DELETED", "Your account has been permanently deleted")
	if c.CurrentRoom != nil {
		c.CurrentRoom.Leave(c)
	}
}

// AddFriendListResponse fetches and sends friend list
func (ah *AuthHandler) AddFriendListResponse(c *Client) {
	friends, err := db.GetFriends(c.ID)
	if err != nil {
		return
	}
	bytes, _ := json.Marshal(protocol.NewMessage(protocol.MsgTypeFriendList, friends))
	c.Send <- bytes
}

// SendAuthOk sends successful authentication response with user stats
func (ah *AuthHandler) SendAuthOk(c *Client, stats *db.UserStats) {
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
