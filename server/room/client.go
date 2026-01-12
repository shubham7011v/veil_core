package room

import (
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 20 * time.Second // Reduced from 60s for faster disconnect detection
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 8192
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// Client represents a connected websocket user
type Client struct {
	Hub         *Manager // Reference to the global manager (or specific room later)
	Conn        *websocket.Conn
	Send        chan []byte
	ID          string // PlayerID (after auth)
	CurrentRoom *Room  // Pointer to room they are in, if any
	IsBot       bool   // True if this is a server-side bot
	IsSpectator bool   // True if joining as a watcher
	Name        string // Display name
	AvatarURL   string // Profile picture URL

	// Rate limiting
	lastActionTime time.Time
	actionCount    int
	mu             sync.Mutex
}

const (
	maxActionsPerSecond = 10
	rateLimitWindow     = time.Second
)

func (c *Client) canPerformAction() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	now := time.Now()

	// Reset counter if window expired
	if now.Sub(c.lastActionTime) > rateLimitWindow {
		c.actionCount = 0
		c.lastActionTime = now
	}

	// Check limit
	if c.actionCount >= maxActionsPerSecond {
		return false
	}

	c.actionCount++
	return true
}

// readPump pumps messages from the websocket connection to the hub.
func (c *Client) ReadPump() {
	defer func() {
		c.Hub.Unregister <- c
		c.Conn.Close()
	}()
	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error { c.Conn.SetReadDeadline(time.Now().Add(pongWait)); return nil })

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			log.Printf("Read error for Client %s: %v", c.ID, err)
			break
		}

		// Handle message via the Manager
		// (We wrap it in a struct or just pass bytes? Let's decode partially here or pass to Hub)
		// For now, pass to Hub for "Global" messages (like Join/Auth),
		// or pass to Room if CurrentRoom is set.

		// NOTE: In a real app we might decode here to route better.
		// For now simple router:
		c.Hub.HandleMessage(c, message)
	}
}

// writePump pumps messages from the hub to the websocket connection.
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ServeWs handles websocket requests from the peer.
func ServeWs(manager *Manager, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println(err)
		return
	}
	client := &Client{Hub: manager, Conn: conn, Send: make(chan []byte, 256)}
	// Use strict timeout for registration to prevent hanging if Manager blocks
	select {
	case client.Hub.Register <- client:
		// Success
	case <-time.After(5 * time.Second):
		log.Printf("ERROR: Manager.Register timed out for connection from %s", r.RemoteAddr)
		conn.Close()
		return
	}

	// Allow collection of memory referenced by the caller by doing all work in
	// new goroutines.
	go client.WritePump()
	go client.ReadPump()
}
