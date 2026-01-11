package room

import (
	"encoding/json"
	"log"
	"math/rand"
	"time"
	"veil_server/game"
	"veil_server/protocol"
)

// BotNameList is a pool of realistic names for bots
var BotNameList = []string{
	"ShadowHunter", "CardMaster99", "BluffKing", "SilentAce", "Viper",
	"Mystic", "Neo", "Trinity", "Cipher", "GhostProtocol",
	"Velvet", "Rogue", "Gambit", "Spectre", "Oracle",
}

// Bot wraps a Client to act as an AI player
type Bot struct {
	Client *Client
}

// NewBot creates a fake Client and a Bot controller
func NewBot(manager *Manager) *Bot {
	// 1. Generate Identity
	rand.Seed(time.Now().UnixNano())
	name := BotNameList[rand.Intn(len(BotNameList))]
	id := "bot_" + generateRandomString(8)

	// 2. Create Client (No Conn, IsBot=true)
	client := &Client{
		Hub:   manager,
		Conn:  nil, // No WebSocket connection
		Send:  make(chan []byte, 256),
		ID:    id,
		Name:  name,
		IsBot: true,
	}

	bot := &Bot{Client: client}

	// 3. Start the Bot Loop
	go bot.Run()

	return bot
}

func (b *Bot) Run() {
	// Listen to Game State updates directed at this bot
	for {
		message, ok := <-b.Client.Send
		if !ok {
			log.Printf("Bot %s disconnected (channel closed)", b.Client.ID)
			return
		}

		// Parse Message
		var baseMsg protocol.BaseMessage
		if err := json.Unmarshal(message, &baseMsg); err != nil {
			continue
		}

		if baseMsg.Type == protocol.MsgTypeGameState {
			var state map[string]interface{}
			if err := json.Unmarshal(baseMsg.Data, &state); err != nil {
				continue
			}

			// Check if it's my turn
			phase, ok := state["phase"].(string)
			if !ok {
				continue
			}

			activeID, _ := state["activePlayerId"].(string)
			if activeID != b.Client.ID {
				continue
			}

			switch phase {
			case string(game.PhaseThinking):
				// It's my turn to play!
				go b.decideMove()
			case string(game.PhaseChallenging):
				// It's my turn to challenge!
				go b.decideChallenge()
			}
		}
	}
}

func (b *Bot) decideMove() {
	// Artificial Delay (1.5s - 3.5s)
	delay := time.Duration(1500+rand.Intn(2000)) * time.Millisecond
	time.Sleep(delay)

	room := b.Client.CurrentRoom
	if room == nil {
		return
	}

	// Simple Strategy:
	// 1. Look at hand
	// 2. Look at declared rank
	// 3. If I have matching cards, play them (Truth)
	// 4. Else, bluff with random cards

	// We need to parse real game structures to do this properly.
	// Since 'state' is a map, it's messy. Accessing Room.Game directly is CHEATING but
	// SAFE ACCESS via Room (since we are in same package)
	// We MUST lock to avoid concurrent map read/write panic
	room.mu.RLock()
	defer room.mu.RUnlock()
	// Use Read Lock if we implemented one, but for now access is mostly safe via channels.
	// Wait, we can't access Game state safely while it might be mutating.
	// But deciding a move doesn't mutate.

	g := room.game
	player := g.PlayerMap[b.Client.ID]
	if player == nil {
		return
	}

	declaredRankPtr := g.DeclaredRank
	var declaredRank game.Rank
	if declaredRankPtr != nil {
		declaredRank = *declaredRankPtr
	}

	// Logic
	// Check if I have cards of declaredRank
	var matchingCards []string
	var otherCards []string

	for _, c := range player.Hand {
		if c.Rank == declaredRank {
			matchingCards = append(matchingCards, c.ID)
		} else {
			otherCards = append(otherCards, c.ID)
		}
	}

	var action string // "PLAY", "PASS", "CHALLENGE" (?)
	// Bots usually don't challenge in this simple version, unless we add logic.
	// Let's implement PLAY logic first.

	var cardsToPlay []string

	newRank := declaredRank

	if g.PileCount == 0 {
		// Pick a rank I have the most of
		counts := make(map[game.Rank]int)
		for _, c := range player.Hand {
			counts[c.Rank]++
		}

		maxCount := 0
		bestRank := game.Rank("two") // Default

		for r, count := range counts {
			if count > maxCount {
				maxCount = count
				bestRank = r
			}
		}
		newRank = bestRank
		// Always play truth for new round if possible
		for _, c := range player.Hand {
			if c.Rank == newRank {
				cardsToPlay = append(cardsToPlay, c.ID)
			}
		}
		action = "PLAY"
	} else {
		// Pile not empty, must follow suite or bluff
		if len(matchingCards) > 0 {
			// Play Truth (1 or 2 cards)
			count := 1 + rand.Intn(len(matchingCards)) // 1 to all
			if count > len(matchingCards) {
				count = len(matchingCards)
			}
			cardsToPlay = matchingCards[:count]
			action = "PLAY"
		} else {
			// Must Bluff or Pass
			// 80% Bluff, 20% Pass (if hand > 1)
			if len(otherCards) > 0 {
				// Bluff
				cardsToPlay = []string{otherCards[0]}
				action = "PLAY"
			} else {
				// No cards? Should probably pass or game over
				action = "PASS"
			}
		}
	}

	// Execute Action
	switch action {
	case "PLAY":
		payload := protocol.PlayCardsMessage{
			CardIDs:      cardsToPlay,
			DeclaredRank: string(newRank),
		}
		data, _ := json.Marshal(payload)

		msg := protocol.BaseMessage{
			Type: protocol.MsgTypePlayCards,
			Data: data,
		}

		room.HandleAction(GameAction{
			Client:  b.Client,
			Message: msg,
		})

	case "PASS":
		msg := protocol.BaseMessage{
			Type: protocol.MsgTypePass,
			Data: []byte("null"),
		}
		room.HandleAction(GameAction{
			Client:  b.Client,
			Message: msg,
		})
	}
}

func (b *Bot) decideChallenge() {
	// Artificial Delay (2s - 4s) for suspense
	delay := time.Duration(2000+rand.Intn(2000)) * time.Millisecond
	time.Sleep(delay)

	room := b.Client.CurrentRoom
	if room == nil {
		return
	}

	// Lock for safe access
	room.mu.RLock()
	defer room.mu.RUnlock()

	g := room.game
	lastMove := g.LastMove
	if lastMove == nil {
		return
	}

	// Heuristic Logic:
	// 1. Base Challenge Probability (10%)
	chance := 0.1

	// 2. Card Count Bonus: More cards played = higher suspicion
	// Each card beyond the first adds 15% suspicion
	cardCount := len(lastMove.ActualCards)
	if cardCount > 1 {
		chance += float64(cardCount-1) * 0.15
	}

	// 3. Hand Knowledge Deduction:
	// If I hold Aces, and you play Aces, and together we have > 4 Aces, you are a LIAR.
	player := g.PlayerMap[b.Client.ID]
	if player != nil {
		myMatchingCount := 0
		for _, c := range player.Hand {
			if c.Rank == lastMove.DeclaredRank {
				myMatchingCount++
			}
		}

		totalSeen := myMatchingCount + cardCount
		if totalSeen > 4 {
			// STATISTICALLY IMPOSSIBLE
			log.Printf("Bot %s detected a definite bluff! (Seen %d %s's)", b.Client.ID, totalSeen, lastMove.DeclaredRank)
			chance = 1.0
		} else if myMatchingCount > 0 {
			// I have some, so the probability of you having THIS MANY is lower
			chance += float64(myMatchingCount) * 0.1
		}
	}

	// Final Decision
	action := protocol.MsgTypePass
	if rand.Float64() < chance {
		action = protocol.MsgTypeChallenge
		log.Printf("Bot %s is CHALLENGING %s's move of %d %s", b.Client.ID, lastMove.PlayerID, cardCount, lastMove.DeclaredRank)
	} else {
		log.Printf("Bot %s is passing on challenge", b.Client.ID)
	}

	room.HandleAction(GameAction{
		Client: b.Client,
		Message: protocol.BaseMessage{
			Type: action,
			Data: []byte("null"),
		},
	})
}

func generateRandomString(n int) string {
	var letters = []rune("abcdefghijklmnopqrstuvwxyz0123456789")
	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}
