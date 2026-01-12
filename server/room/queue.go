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
func (q *MatchmakingQueue) Tick() (clients []*Client, matchType string) {
	if len(q.items) == 0 {
		return nil, ""
	}

	// 1. Check for immediate full match (5 players)
	if len(q.items) >= 5 {
		matchClients := make([]*Client, 0)
		for i := 0; i < 5; i++ {
			matchClients = append(matchClients, q.items[i].Client)
		}
		q.items = q.items[5:]
		return matchClients, "MATCH"
	}

	// 2. Check Head Timeout (10 seconds)
	head := q.items[0]
	if time.Since(head.EntryTime) < 10*time.Second {
		return nil, ""
	}

	// 3. Timeout Reached
	// Gather all clients currently in queue
	matchClients := make([]*Client, 0)
	for _, item := range q.items {
		matchClients = append(matchClients, item.Client)
	}
	q.items = nil // Clear queue

	log.Printf("Queue: Timeout reached. Starting match with %d players.", len(matchClients))
	return matchClients, "MATCH"
}
