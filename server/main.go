package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"veil_server/api"
	"veil_server/config"
	"veil_server/db"
	"veil_server/room"

	firebase "firebase.google.com/go/v4"
	"google.golang.org/api/option"
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

	// Initialize Firebase Admin SDK
	// Credentials can be provided via GOOGLE_APPLICATION_CREDENTIALS env var (path to JSON)
	// OR via raw JSON string in FIREBASE_CREDENTIALS_JSON env var (better for clouds like Heroku/Render)
	ctx := context.Background()
	var app *firebase.App
	var err error

	credJSON := os.Getenv("FIREBASE_CREDENTIALS_JSON")
	if credJSON != "" {
		opt := option.WithCredentialsJSON([]byte(credJSON))
		app, err = firebase.NewApp(ctx, nil, opt)
	} else {
		// Fallback to auto-discovery (GOOGLE_APPLICATION_CREDENTIALS)
		app, err = firebase.NewApp(ctx, nil)
	}

	if err != nil {
		log.Fatalf("error initializing firebase app: %v\n", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		log.Fatalf("error getting Auth client: %v\n", err)
	}

	// Initialize the Room Manager
	manager := room.NewManager()
	go manager.Run()

	// Handle WebSocket connections
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		room.ServeWs(manager, w, r)
	})

	// Admin API
	adminHandler := api.NewAdminHandler(manager, authClient)
	http.HandleFunc("/api/admin/stats", adminHandler.AdminMiddleware(adminHandler.GetStats))
	http.HandleFunc("/api/admin/rooms", adminHandler.AdminMiddleware(adminHandler.ListRooms))
	http.HandleFunc("/api/admin/rooms/close", adminHandler.AdminMiddleware(adminHandler.CloseRoom))
	http.HandleFunc("/api/admin/broadcast", adminHandler.AdminMiddleware(adminHandler.Broadcast))
	http.HandleFunc("/api/admin/users/ban", adminHandler.AdminMiddleware(adminHandler.BanUser))

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
