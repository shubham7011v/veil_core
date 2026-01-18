package social

// Repository defines the interface for social graph operations
type Repository interface {
	// AddFriendRequest creates a pending friend request
	AddFriendRequest(userID, friendID string) error

	// AcceptFriendRequest accepts a pending request (bidirectional)
	AcceptFriendRequest(userID, friendID string) error

	// RemoveFriend removes a friendship or cancels a request
	RemoveFriend(userID, friendID string) error

	// GetFriends returns a list of friends with their status and details
	GetFriends(userID string) ([]Friend, error)

	// GetPendingRequests returns incoming friend requests
	GetPendingRequests(userID string) ([]Friend, error)
}
