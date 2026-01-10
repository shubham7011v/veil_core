package api

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"runtime"
	"strings"
	"time"
	"veil_server/config"
	"veil_server/db"
	"veil_server/room"

	"firebase.google.com/go/v4/auth"
)

// AdminHandler handles administrative requests
type AdminHandler struct {
	Manager    *room.Manager
	AuthClient *auth.Client
}

func NewAdminHandler(m *room.Manager, auth *auth.Client) *AdminHandler {
	return &AdminHandler{
		Manager:    m,
		AuthClient: auth,
	}
}

// AdminMiddleware ensures the request has a valid Firebase ID token and the UID is authorized
func (h *AdminHandler) AdminMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// 0. Handle CORS Preflight
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		// Check if Admin Dashboard is enabled
		if !config.GetFeatureFlags().EnableAdminDashboard {
			http.Error(w, "Forbidden: Admin Dashboard is disabled", http.StatusForbidden)
			return
		}

		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Unauthorized: Missing Authorization header", http.StatusUnauthorized)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, "Unauthorized: Invalid Authorization header format", http.StatusUnauthorized)
			return
		}

		idToken := parts[1]
		log.Printf("ADMIN_CHECK: Verifying token for request to %s...", r.URL.Path)

		// 1. Verify Firebase Token
		idCtx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		token, err := h.AuthClient.VerifyIDToken(idCtx, idToken)
		if err != nil {
			log.Printf("ADMIN_CHECK: Token verification failed: %v", err)
			http.Error(w, "Unauthorized: Invalid token", http.StatusUnauthorized)
			return
		}
		log.Printf("ADMIN_CHECK: Token verified successfully. UID: %s", token.UID)

		// 2. Check if UID is in allowed list
		adminUIDsEnv := os.Getenv("ADMIN_UIDS")
		log.Printf("ADMIN_CHECK: Env var ADMIN_UIDS length: %d", len(adminUIDsEnv))
		if adminUIDsEnv == "" {
			log.Println("WARNING: ADMIN_UIDS env var is empty. Admin access denied for everything.")
			http.Error(w, "Forbidden: Server misconfiguration", http.StatusForbidden)
			return
		}

		allowedUIDs := strings.Split(adminUIDsEnv, ",")
		isAllowed := false
		trimmedTokenUID := strings.TrimSpace(token.UID)

		for _, uid := range allowedUIDs {
			trimmedAllowedUID := strings.TrimSpace(uid)
			if trimmedAllowedUID == trimmedTokenUID {
				isAllowed = true
				break
			}
		}

		if !isAllowed {
			log.Printf("ADMIN_CHECK: DENIED - UID %s not in whitelist", token.UID)
			http.Error(w, "Forbidden: Not an admin", http.StatusForbidden)
			return
		}

		log.Printf("ADMIN_CHECK: GRANTED - UID %s proceeding to %s", token.UID, r.URL.Path)
		// Success! Proceed.
		next(w, r)
	}
}

// Ping checks server health without auth
func (h *AdminHandler) Ping(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"pong", "time":"` + time.Now().Format(time.RFC3339) + `"}`))
}

// ServerStats struct
type ServerStats struct {
	Goroutines int `json:"goroutines"`
	Uptime     int `json:"uptime_sec"`
}

var startTime = time.Now()

// GetStats returns server health metrics
func (h *AdminHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	stats := ServerStats{
		Goroutines: runtime.NumGoroutine(),
		Uptime:     int(time.Since(startTime).Seconds()),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

// ListRooms returns all active rooms
func (h *AdminHandler) ListRooms(w http.ResponseWriter, r *http.Request) {
	rooms := h.Manager.GetActiveRooms()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rooms)
}

// Broadcast sends a system message to all connected clients
func (h *AdminHandler) Broadcast(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		Message string `json:"message"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	h.Manager.BroadcastSystemMessage(payload.Message)
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}

// BanUser bans a user and kicks them if they are connected
func (h *AdminHandler) BanUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		UserID string `json:"userId"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	// 1. Mark as banned in DB
	if err := db.BanUser(payload.UserID); err != nil {
		log.Printf("Error banning user in DB: %v", err)
	}
	log.Printf("Banning user: %s", payload.UserID)

	// 2. Kick from manager
	h.Manager.KickUser(payload.UserID, "You have been banned by an administrator.")

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}

// CloseRoom forcefully closes a room
func (h *AdminHandler) CloseRoom(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		RoomID string `json:"roomId"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	// TODO: Implement ForceClose in Manager
	// This is a placeholder until we add the method to Manager
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}
