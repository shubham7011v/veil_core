package game

import (
	"math/rand"
	"time"
)

// -- Enums --

type Suit string

const (
	Spades   Suit = "spades"
	Hearts   Suit = "hearts"
	Diamonds Suit = "diamonds"
	Clubs    Suit = "clubs"
)

type Rank string

const (
	RankTwo   Rank = "two"
	RankThree Rank = "three"
	RankFour  Rank = "four"
	RankFive  Rank = "five"
	RankSix   Rank = "six"
	RankSeven Rank = "seven"
	RankEight Rank = "eight"
	RankNine  Rank = "nine"
	RankTen   Rank = "ten"
	RankJack  Rank = "jack"
	RankQueen Rank = "queen"
	RankKing  Rank = "king"
	RankAce   Rank = "ace"
)

// -- Structs --

type Card struct {
	ID   string `json:"id"`
	Suit Suit   `json:"type"` // Matching Dart's 'type' field
	Rank Rank   `json:"rank"`
}

// -- Deck Logic --

func NewDeck() []Card {
	suits := []Suit{Spades, Hearts, Diamonds, Clubs}
	ranks := []Rank{
		RankTwo, RankThree, RankFour, RankFive, RankSix, RankSeven,
		RankEight, RankNine, RankTen, RankJack, RankQueen, RankKing, RankAce,
	}

	deck := []Card{}
	idCounter := 0

	for _, s := range suits {
		for _, r := range ranks {
			// Simple ID generation for now. 
			// In production, maybe use UUID or generic IDs.
			// Dart app uses UUIDs usually, but simple string valid too.
			id := string(r) + "_of_" + string(s) 
			deck = append(deck, Card{
				ID:   id,
				Suit: s,
				Rank: r,
			})
			idCounter++
		}
	}
	
	// Shuffle
	rand.Seed(time.Now().UnixNano())
	rand.Shuffle(len(deck), func(i, j int) {
		deck[i], deck[j] = deck[j], deck[i]
	})

	return deck
}
