package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"os/signal"
	"syscall"
	"time"

	"veil_server/api"
	"veil_server/config"
	"veil_server/db"
	"veil_server/room"
	"veil_server/version"

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
	manager := room.NewManager(authClient)
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
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(config.GetFeatureFlags())
	})

	// Version endpoint
	http.HandleFunc("/api/version", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"version": version.GetVersion()})
	})

	// Create server
	srv := &http.Server{
		Addr: ":" + port,
	}

	// Channel to listen for shutdown signals
	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		log.Printf("Veil Server v%s listening on :%s", version.GetVersion(), port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	// Wait for shutdown signal
	<-done
	log.Println("Server is shutting down...")

	// 1. Notify all connected clients
	manager.BroadcastSystemMessage("Server is restarting for maintenance. Please wait 10 seconds.")
	time.Sleep(2 * time.Second) // Give time for message to reach clients

	// 2. Shut down the HTTP server with 5s timeout
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Server Shutdown Failed:%+v", err)
	}

	log.Println("Server exited gracefully")
}
