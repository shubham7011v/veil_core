package room

import (
	"encoding/json"
	"log"
	"math/rand"
	"time"
	"veil_server/game"
	"veil_server/protocol"
)

// ✅ FIX #10: Removed deprecated rand.Seed() - Go 1.20+ auto-seeds

// BotNameList is a pool of realistic names for bots
var BotNameList = []string{
	"Shubham", "Julie", "Shivam", "Sandhya", "Sabhya",
	"Sanchit", "Satyam", "Sarvottam", "Dipesh", "Divyam",
	"Rashmi", "Gaurav", "Saurav", "Nitish", "Nishu",
	"Aarush", "Arman", "Riya", "Angel", "Mushkan",
}

// Bot wraps a Client to act as an AI player
type Bot struct {
	Client      *Client
	Personality game.Personality
}

// NewBot creates a fake Client and a Bot controller
func NewBot(manager *Manager) *Bot {
	// 1. Generate Identity
	name := BotNameList[rand.Intn(len(BotNameList))]
	id := "bot_" + generateRandomString(8)

	// 2. Assign Personality
	personalities := []game.Personality{
		game.PersonalityConservative,
		game.PersonalityAggressive,
		game.PersonalityBalanced,
		game.PersonalityGhost,
	}
	personality := personalities[rand.Intn(len(personalities))]

	// 3. Create Client (No Conn, IsBot=true)
	client := &Client{
		Hub:   manager,
		Conn:  nil, // No WebSocket connection
		Send:  make(chan []byte, 256),
		ID:    id,
		Name:  name,
		IsBot: true,
	}

	bot := &Bot{
		Client:      client,
		Personality: personality,
	}

	log.Printf("Created Bot %s with personality %s", name, personality)

	// 4. Start the Bot Loop
	go bot.Run()

	return bot
}

func (b *Bot) Run() {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Bot %s (%s) panic recovered: %v", b.Client.ID, b.Client.Name, r)
		}
	}()

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
	// Artificial Delay (Fixed 10s + small variance for human feel)
	delay := time.Duration(10000+rand.Intn(1500)) * time.Millisecond
	time.Sleep(delay)

	room := b.Client.CurrentRoom
	if room == nil {
		return
	}

	room.mu.RLock()
	g := room.game
	player := g.PlayerMap[b.Client.ID]
	room.mu.RUnlock()

	if player == nil || len(player.Hand) == 0 {
		return
	}

	// 1. Pass Chance based on Personality (Dart matching)
	passChance := 0.15 // Default (Balanced, Aggressive)
	switch b.Personality {
	case game.PersonalityGhost:
		passChance = 0.45
	case game.PersonalityConservative:
		passChance = 0.25
	}

	if rand.Float64() < passChance && g.PileCount > 0 {
		b.executePass(room)
		return
	}

	// 2. Rank Selection
	declaredRankPtr := g.DeclaredRank
	var targetRank game.Rank
	isStartingRound := declaredRankPtr == nil

	if isStartingRound {
		// Pick a rank I have the most of
		counts := make(map[game.Rank]int)
		for _, c := range player.Hand {
			counts[c.Rank]++
		}
		maxCount := 0
		for r, count := range counts {
			if count > maxCount {
				maxCount = count
				targetRank = r
			}
		}
	} else {
		targetRank = *declaredRankPtr
	}

	matchingCards := []string{}
	otherCards := []string{}
	for _, c := range player.Hand {
		if c.Rank == targetRank {
			matchingCards = append(matchingCards, c.ID)
		} else {
			otherCards = append(otherCards, c.ID)
		}
	}

	cardsToPlay := []string{}

	// 3. Play Logic based on Personality
	switch b.Personality {
	case game.PersonalityAggressive:
		if len(matchingCards) > 0 && rand.Float64() > 0.2 {
			// Play Truth
			count := len(matchingCards)
			if count > 4 {
				count = 4
			}
			cardsToPlay = matchingCards[:count]
		} else {
			// Bluff
			count := 1 + rand.Intn(3)
			if count > len(player.Hand) {
				count = len(player.Hand)
			}
			// Shuffle otherCards or player.Hand to pick random
			shuffled := append([]string{}, otherCards...)
			rand.Shuffle(len(shuffled), func(i, j int) { shuffled[i], shuffled[j] = shuffled[j], shuffled[i] })
			cardsToPlay = shuffled[:count]
		}

	case game.PersonalityConservative:
		if len(matchingCards) > 0 {
			cardsToPlay = []string{matchingCards[0]}
		} else if rand.Float64() < 0.1 {
			// Rare bluff
			cardsToPlay = []string{player.Hand[rand.Intn(len(player.Hand))].ID}
		} else if !isStartingRound {
			b.executePass(room)
			return
		}

	default: // Balanced / Ghost
		if len(matchingCards) > 0 && rand.Float64() > 0.4 {
			count := 1 + rand.Intn(2)
			if count > len(matchingCards) {
				count = len(matchingCards)
			}
			cardsToPlay = matchingCards[:count]
		} else if len(player.Hand) > 0 {
			count := 1 + rand.Intn(2)
			if count > len(player.Hand) {
				count = len(player.Hand)
			}
			shuffled := append([]string{}, player.HandIDs()...)
			for i := range shuffled {
				j := rand.Intn(i + 1)
				shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
			}
			cardsToPlay = shuffled[:count]
		}
	}

	if len(cardsToPlay) == 0 {
		b.executePass(room)
	} else {
		b.executePlay(room, cardsToPlay, targetRank)
	}
}

func (b *Bot) executePlay(room *Room, cardIDs []string, rank game.Rank) {
	payload := protocol.PlayCardsMessage{
		CardIDs:      cardIDs,
		DeclaredRank: string(rank),
	}
	data, _ := json.Marshal(payload)
	room.HandleAction(GameAction{
		Client: b.Client,
		Message: protocol.BaseMessage{
			Type: protocol.MsgTypePlayCards,
			Data: data,
		},
	})
}

func (b *Bot) executePass(room *Room) {
	room.HandleAction(GameAction{
		Client: b.Client,
		Message: protocol.BaseMessage{
			Type: protocol.MsgTypePass,
			Data: []byte("null"),
		},
	})
}

func (b *Bot) decideChallenge() {
	// Artificial Delay (Fixed 10s + small variance for suspense)
	delay := time.Duration(10000+rand.Intn(1500)) * time.Millisecond
	time.Sleep(delay)

	room := b.Client.CurrentRoom
	if room == nil {
		return
	}

	room.mu.RLock()
	g := room.game
	lastMove := g.LastMove
	player := g.PlayerMap[b.Client.ID]
	room.mu.RUnlock()

	if lastMove == nil || player == nil || lastMove.PlayerID == b.Client.ID {
		return
	}

	// 1. Base Challenge Probability based on Personality (Matching Dart logic)
	chance := 0.15 // Default (Balanced, Ghost)
	switch b.Personality {
	case game.PersonalityAggressive:
		chance = 0.35
	case game.PersonalityConservative:
		if g.PileCount > 8 {
			chance = 0.25
		} else {
			chance = 0.05
		}
	}

	// 2. Statistical Knowledge (Keep Go's advanced detection)
	// If I hold some, and you play some, and total > 4 -> 100% chance
	myMatchingCount := 0
	for _, c := range player.Hand {
		if c.Rank == lastMove.DeclaredRank {
			myMatchingCount++
		}
	}

	totalSeen := myMatchingCount + len(lastMove.ActualCards)
	if totalSeen > 4 {
		chance = 1.0
		log.Printf("Bot %s (Personality: %s) detected a definite bluff!", b.Client.ID, b.Personality)
	}

	// Final Decision
	action := protocol.MsgTypePass
	if rand.Float64() < chance {
		action = protocol.MsgTypeChallenge
		log.Printf("Bot %s (%s) is CHALLENGING %s", b.Client.ID, b.Personality, lastMove.PlayerID)
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
