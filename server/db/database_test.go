package db

import (
	"os"
	"testing"
	"time"
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

func TestLeaderboard(t *testing.T) {
	tmpDB := "./test_leaderboard_veil.db"
	os.Remove(tmpDB)
	defer os.Remove(tmpDB)

	if err := InitDB(tmpDB); err != nil {
		t.Fatalf("InitDB failed: %v", err)
	}

	// Create players with different win counts
	players := []struct {
		id   string
		name string
		wins int
	}{
		{"p1", "Alice", 10},
		{"p2", "Bob", 5},
		{"p3", "Charlie", 20},
	}

	for _, p := range players {
		// Insert directly or via RecordGameResult. Insertion is easier for setup.
		DB.Exec("INSERT INTO users (user_id, name, wins) VALUES (?, ?, ?)", p.id, p.name, p.wins)
	}

	lb, err := GetLeaderboard()
	if err != nil {
		t.Fatalf("GetLeaderboard failed: %v", err)
	}

	if len(lb) != 3 {
		t.Fatalf("Expected 3 players, got %d", len(lb))
	}

	// Check order (should be Charlie, Alice, Bob)
	if lb[0].UserID != "p3" || lb[1].UserID != "p1" || lb[2].UserID != "p2" {
		t.Errorf("Incorrect leaderboard order: %v", lb)
	}
}

func TestFriends(t *testing.T) {
	tmpDB := "./test_friends_veil.db"
	os.Remove(tmpDB)
	defer os.Remove(tmpDB)

	if err := InitDB(tmpDB); err != nil {
		t.Fatalf("InitDB failed: %v", err)
	}

	// Setup users
	DB.Exec("INSERT INTO users (user_id, name, last_seen) VALUES ('u1', 'Alice', ?)", time.Now().Add(-10*time.Minute))
	DB.Exec("INSERT INTO users (user_id, name, last_seen) VALUES ('u2', 'Bob', ?)", time.Now())

	// 1. Send Request
	if err := AddFriend("u1", "u2"); err != nil {
		t.Fatalf("AddFriend failed: %v", err)
	}

	// Verify pending for u1
	fs, _ := GetFriends("u1")
	if len(fs) != 1 || fs[0].Status != "pending" {
		t.Errorf("Expected pending friend, got: %v", fs)
	}

	// 2. Accept Request
	if err := AcceptFriend("u2", "u1"); err != nil {
		t.Fatalf("AcceptFriend failed: %v", err)
	}

	// Verify accepted for both
	fs1, _ := GetFriends("u1")
	if fs1[0].Status != "accepted" || fs1[0].FriendID != "u2" || fs1[0].IsOnline != true {
		t.Errorf("Alice friend list incorrect: %v", fs1)
	}

	fs2, _ := GetFriends("u2")
	if len(fs2) != 1 || fs2[0].Status != "accepted" || fs2[0].FriendID != "u1" || fs2[0].IsOnline != false {
		t.Errorf("Bob friend list incorrect: %v", fs2)
	}
}
