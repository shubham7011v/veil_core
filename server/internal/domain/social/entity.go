package social

import "time"

// FriendStatus represents the state of a friendship
type FriendStatus string

const (
	FriendStatusPending  FriendStatus = "pending"
	FriendStatusAccepted FriendStatus = "accepted"
)

// Friend represents a social connection between users
type Friend struct {
	UserID    string       `json:"userId"`
	FriendID  string       `json:"friendId"`
	Status    FriendStatus `json:"status"`
	Name      string       `json:"name,omitempty"`      // Denormalized/Fetched name
	Rank      string       `json:"rank,omitempty"`      // Denormalized/Fetched rank
	AvatarURL string       `json:"avatarUrl,omitempty"` // Denormalized/Fetched avatar
	LastSeen  time.Time    `json:"lastSeen,omitempty"`
	IsOnline  bool         `json:"isOnline,omitempty"`
	CreatedAt time.Time    `json:"createdAt"`
}
