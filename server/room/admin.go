package room

import (
	"encoding/json"
	"net/http"
	"os"
)

// AdminHandler handles administrative requests
type AdminHandler struct {
	manager *Manager
}

func NewAdminHandler(manager *Manager) *AdminHandler {
	return &AdminHandler{manager: manager}
}

// AdminMiddleware checks for a valid admin key
func (h *AdminHandler) AdminMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		apiKey := r.Header.Get("X-Admin-Key")
		expectedKey := os.Getenv("ADMIN_API_KEY")

		if expectedKey == "" {
			expectedKey = "veil-admin-secret-2024" // Default for dev
		}

		if apiKey != expectedKey {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

// GetStats returns global server statistics
func (h *AdminHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	h.manager.mu.RLock()
	defer h.manager.mu.RUnlock()

	totalPlayers := 0
	for _, room := range h.manager.Rooms {
		room.mu.RLock()
		totalPlayers += len(room.clients)
		room.mu.RUnlock()
	}

	stats := map[string]interface{}{
		"total_rooms":   len(h.manager.Rooms),
		"total_players": totalPlayers,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

// ListRooms returns a list of all active rooms
func (h *AdminHandler) ListRooms(w http.ResponseWriter, r *http.Request) {
	h.manager.mu.RLock()
	defer h.manager.mu.RUnlock()

	rooms := make([]map[string]interface{}, 0)
	for id, room := range h.manager.Rooms {
		room.mu.RLock()
		rooms = append(rooms, map[string]interface{}{
			"id":           id,
			"player_count": len(room.clients),
			"is_private":   room.session.Settings.IsPrivate,
			"game_started": room.session.Game != nil,
		})
		room.mu.RUnlock()
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rooms)
}

// CloseRoom forcefully shuts down a room
func (h *AdminHandler) CloseRoom(w http.ResponseWriter, r *http.Request) {
	roomID := r.URL.Query().Get("id")
	if roomID == "" {
		http.Error(w, "Missing room id", http.StatusBadRequest)
		return
	}

	h.manager.mu.Lock()
	room, exists := h.manager.Rooms[roomID]
	if exists {
		delete(h.manager.Rooms, roomID)
	}
	h.manager.mu.Unlock()

	if !exists {
		http.Error(w, "Room not found", http.StatusNotFound)
		return
	}

	// Notify clients (simplified)
	room.mu.RLock()
	for client := range room.clients {
		client.Conn.Close()
	}
	room.mu.RUnlock()

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Room closed"))
}
