package main

import (
	"log"
	"net/http"
	"os"

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

	log.Printf("Veil Server listening on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal("ListenAndServe:", err)
	}
}
