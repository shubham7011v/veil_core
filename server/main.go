package main

import (
	"log"
	"net/http"
	"os"

	"encoding/json"
	"veil_server/api"
	"veil_server/config"
	"veil_server/db"
	"veil_server/room"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Initialize Database
	if err := db.InitDB("/app/data/veil.db"); err != nil {
		// Fallback for local dev if /app/data doesn't exist
		if err := db.InitDB("./veil.db"); err != nil {
			log.Fatal("Failed to init DB:", err)
		}
	}

	// Initialize the Room Manager
	manager := room.NewManager()
	go manager.Run()

	// Handle WebSocket connections
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		room.ServeWs(manager, w, r)
	})

	// Admin API
	adminHandler := api.NewAdminHandler(manager)
	http.HandleFunc("/api/admin/stats", adminHandler.AdminMiddleware(adminHandler.GetStats))
	http.HandleFunc("/api/admin/rooms", adminHandler.AdminMiddleware(adminHandler.ListRooms))
	http.HandleFunc("/api/admin/rooms/close", adminHandler.AdminMiddleware(adminHandler.CloseRoom))

	// Public Config
	http.HandleFunc("/api/config", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(config.GetFeatureFlags())
	})

	log.Printf("Veil Server listening on :%s", port)
	// TODO: Implement graceful shutdown handling for better reliability
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal("ListenAndServe:", err)
	}
}
