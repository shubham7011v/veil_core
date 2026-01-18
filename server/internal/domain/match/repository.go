package match

type Repository interface {
	// SaveResult persists the match record and updates user stats (wins/losses)
	SaveResult(result MatchResult) error
}
