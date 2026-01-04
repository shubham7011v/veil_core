package db

import (
	"os"
	"testing"
)

func TestUserStats(t *testing.T) {
	tmpDB := "./test_veil.db"
	os.Remove(tmpDB) // Clean start
	defer os.Remove(tmpDB)

	if err := InitDB(tmpDB); err != nil {
		t.Fatalf("InitDB failed: %v", err)
	}

	// 1. Create User
	u1, err := GetOrCreateUser("user1", "Alice")
	if err != nil {
		t.Fatalf("GetOrCreateUser failed: %v", err)
	}
	if u1.Name != "Alice" || u1.Wins != 0 {
		t.Errorf("Unexpected user state: %+v", u1)
	}

	// 2. Fetch Existing
	u2, err := GetOrCreateUser("user1", "Alice2")
	if err != nil {
		t.Fatalf("GetOrCreateUser fetch failed: %v", err)
	}
	if u2.Name != "Alice" { // Name should NOT change on plain fetch
		t.Errorf("Name mismatch: %s", u2.Name)
	}

	// 3. Record Match
	err = RecordGameResult("match_1", []string{"user1", "user2"}, "user1", 60)
	if err != nil {
		t.Fatalf("RecordGameResult failed: %v", err)
	}

	// 4. Verify Stats
	u1After, _ := GetOrCreateUser("user1", "")
	if u1After.Wins != 1 || u1After.GamesPlayed != 1 {
		t.Errorf("Winner stats incorrect: %+v", u1After)
	}

	u2After, _ := GetOrCreateUser("user2", "Bob")
	if u2After.Losses != 1 || u2After.GamesPlayed != 1 {
		t.Errorf("Loser stats incorrect: %+v", u2After)
	}
}
