package main

import (
	"log"
	"net/http"
	"os"

	"veil_server/room"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
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
