package main

import (
	"context"
	"database/sql"
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
	var dbConn *sql.DB
	var err error
	dbConn, err = db.InitDB("/app/data/veil.db")
	if err != nil {
		// Fallback for local dev if /app/data doesn't exist
		dbConn, err = db.InitDB("./veil.db")
		if err != nil {
			log.Fatal("Failed to init DB:", err)
		}
	}

	// Start internal background workers for DB cleanup are now handled by Manager

	// Initialize Firebase Admin SDK
	ctx := context.Background()
	var app *firebase.App

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

	// Initialize the Room Manager with dependency injection
	manager := room.NewManager(authClient, dbConn)
	go manager.Run()

	// Handle WebSocket connections
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		room.ServeWs(manager, w, r)
	})

	// User API
	userHandler := api.NewUserHandler(authClient, manager.UserRepo)
	http.HandleFunc("/api/user/avatar", userHandler.UploadAvatar)

	// Admin API
	adminHandler := api.NewAdminHandler(manager, authClient)
	http.HandleFunc("/api/admin/ping", adminHandler.Ping)
	http.HandleFunc("/api/admin/stats", adminHandler.AdminMiddleware(adminHandler.GetStats))
	http.HandleFunc("/api/admin/rooms", adminHandler.AdminMiddleware(adminHandler.ListRooms))
	http.HandleFunc("/api/admin/rooms/close", adminHandler.AdminMiddleware(adminHandler.CloseRoom))
	http.HandleFunc("/api/admin/broadcast", adminHandler.AdminMiddleware(adminHandler.Broadcast))
	http.HandleFunc("/api/admin/users/ban", adminHandler.AdminMiddleware(adminHandler.BanUser))

	// Static Files (Avatars, etc)
	fs := http.FileServer(http.Dir("./uploads"))
	http.Handle("/uploads/", http.StripPrefix("/uploads/", fs))

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
		log.Printf("Server Shutdown Failed: %+v", err)
	}

	// 2.5 Stop all rooms
	manager.Shutdown()

	// 3. Flush all buffered coin updates to DB
	log.Println("Flushing coin buffer...")
	if err := manager.FlushEconomy(); err != nil {
		log.Printf("Error flushing coins during shutdown: %v", err)
	}

	log.Println("Server exited gracefully")
}
