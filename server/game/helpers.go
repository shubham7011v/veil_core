package game

// DefaultPlayerName returns a default player name if the provided name is empty.
// This centralizes the player name defaulting logic used across the codebase.
func DefaultPlayerName(playerID, name string) string {
	if name != "" {
		return name
	}
	return "Player " + playerID
}
