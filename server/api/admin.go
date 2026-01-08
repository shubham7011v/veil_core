package api

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"runtime"
	"time"
	"veil_server/db"
	"veil_server/room"
)

// AdminHandler handles administrative requests
type AdminHandler struct {
	Manager *room.Manager
}

func NewAdminHandler(m *room.Manager) *AdminHandler {
	return &AdminHandler{Manager: m}
}

// AdminMiddleware ensures the request has the correct X-Admin-Key
func (h *AdminHandler) AdminMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Key injected from GitHub Secrets / Env Var
		masterKey := os.Getenv("ADMIN_API_KEY")
		if masterKey == "" {
			masterKey = "VEIL_MASTER_KEY_2026" // Default fallback for local dev
		}

		clientKey := r.Header.Get("X-Admin-Key")
		if clientKey != masterKey {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		next(w, r)
	}
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
