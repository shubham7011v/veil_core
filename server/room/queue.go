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

	// 1. Pair 2 Human Players
	if len(q.items) >= 2 {
		c1 := q.items[0].Client
		c2 := q.items[1].Client

		q.items = q.items[2:] // Pop 2
		return []*Client{c1, c2}, "HUMAN"
	}

	// 2. Timeout -> Bot Match
	if len(q.items) == 1 {
		item := q.items[0]
		if time.Since(item.EntryTime) > 10*time.Second {
			log.Printf("Queue: Timeout for %s, requesting Bot.", item.Client.ID)
			q.items = make([]*QueueItem, 0) // Clear
			return []*Client{item.Client}, "BOT"
		}
	}

	return nil, ""
}
