package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
	"veil_server/internal/domain/user"

	"firebase.google.com/go/v4/auth"
)

type UserHandler struct {
	AuthClient *auth.Client
	UserRepo   user.Repository
}

func NewUserHandler(auth *auth.Client, repo user.Repository) *UserHandler {
	return &UserHandler{
		AuthClient: auth,
		UserRepo:   repo,
	}
}

// UploadAvatar handles authenticated multipart uploads of profile pictures (max 100KB)
func (h *UserHandler) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	// 1. Setup CORS
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// 2. Auth Check
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
		http.Error(w, "Unauthorized: Invalid header", http.StatusUnauthorized)
		return
	}

	idToken := strings.TrimPrefix(authHeader, "Bearer ")
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	token, err := h.AuthClient.VerifyIDToken(ctx, idToken)
	if err != nil {
		log.Printf("Token verification failed: %v", err)
		http.Error(w, "Unauthorized: Invalid token", http.StatusUnauthorized)
		return
	}
	userID := token.UID

	// 3. Size Restriction (100 KB)
	r.Body = http.MaxBytesReader(w, r.Body, 100*1024)
	if err := r.ParseMultipartForm(100 * 1024); err != nil {
		http.Error(w, "File too large. Max 100KB allowed.", http.StatusRequestEntityTooLarge)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Invalid file field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// 4. Content Type Validation
	contentType := header.Header.Get("Content-Type")
	allowedTypes := map[string]bool{
		"image/jpeg": true,
		"image/png":  true,
		"image/webp": true,
	}
	if !allowedTypes[contentType] {
		http.Error(w, "Invalid file type. Only JPG, PNG, and WEBP allowed.", http.StatusBadRequest)
		return
	}

	// 5. Save Locally
	uploadDir := "./uploads/avatars"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		parts := strings.Split(contentType, "/")
		if len(parts) == 2 {
			ext = "." + parts[1]
		}
	}
	filename := fmt.Sprintf("%s_%d%s", userID, time.Now().Unix(), ext)
	filePath := filepath.Join(uploadDir, filename)

	out, err := os.Create(filePath)
	if err != nil {
		http.Error(w, "Failed to create file", http.StatusInternalServerError)
		return
	}
	defer out.Close()

	if _, err := io.Copy(out, file); err != nil {
		http.Error(w, "Failed to save file", http.StatusInternalServerError)
		return
	}

	// 6. Update DB
	relativeURL := fmt.Sprintf("/uploads/avatars/%s", filename)
	if err := h.UserRepo.UpdateProfile(userID, "", relativeURL); err != nil {
		log.Printf("Failed to update user avatar in DB: %v", err)
	}

	// 7. Response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"url":      relativeURL,
		"filename": filename,
	})
}
