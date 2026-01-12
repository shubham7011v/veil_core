package room

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"strings"
	"time"

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
		token, err := ah.manager.AuthClient.VerifyIDToken(context.Background(), tokenString)
		if err == nil {
			userID = token.UID
			if firebaseName == "" && token.Claims["name"] != nil {
				firebaseName = token.Claims["name"].(string)
			}
			if firebaseAvatar == "" && token.Claims["picture"] != nil {
				firebaseAvatar = token.Claims["picture"].(string)
			}
		} else {
			log.Printf("Token verify failed: %v", err)
			ah.manager.sendError(c, "AUTH_FAILED", "Invalid authentication token")
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
