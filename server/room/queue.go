package room

import (
	"log"
	"time"
)

type QueueItem struct {
	Client    *Client
	EntryTime time.Time
}

type MatchmakingQueue struct {
	items []*QueueItem
}

func NewMatchmakingQueue() *MatchmakingQueue {
	return &MatchmakingQueue{
		items: make([]*QueueItem, 0),
	}
}

func (q *MatchmakingQueue) Add(c *Client) {
	// Deduplicate
	for _, item := range q.items {
		if item.Client == c {
			return
		}
	}

	q.items = append(q.items, &QueueItem{
		Client:    c,
		EntryTime: time.Now(),
	})
	log.Printf("Queue: Added %s. Size: %d", c.ID, len(q.items))
}

func (q *MatchmakingQueue) Remove(c *Client) {
	newItems := make([]*QueueItem, 0)
	for _, item := range q.items {
		if item.Client != c {
			newItems = append(newItems, item)
		}
	}
	q.items = newItems
}

// Tick checks for matches or timeouts.
// Returns a list of Clients to be matched into a room, or nil.
// If hasBot is true, the last client in the returned list is a Bot that needs to be created.
func (q *MatchmakingQueue) Tick() (clients []*Client, matchType string) {
	if len(q.items) == 0 {
		return nil, ""
	}

	// 1. Check Head Timeout
	head := q.items[0]
	if time.Since(head.EntryTime) < 10*time.Second {
		// Wait for more players to accumulate
		return nil, ""
	}

	// 2. Timeout Reached
	// Gather all clients currently in queue (Limit to 5)
	matchClients := make([]*Client, 0)
	limit := 5
	if len(q.items) < limit {
		limit = len(q.items)
	}

	for i := 0; i < limit; i++ {
		matchClients = append(matchClients, q.items[i].Client)
	}
	q.items = q.items[limit:]

	if len(matchClients) >= 2 {
		log.Printf("Queue: Matched %d humans after timeout.", len(matchClients))
		return matchClients, "MATCH"
	}

	// Single player timeout -> Request Bots
	log.Printf("Queue: Timeout for single player %s, requesting Bot.", matchClients[0].ID)
	return matchClients, "BOT"

}
