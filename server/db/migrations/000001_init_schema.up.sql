-- Users Table
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    name TEXT,
    avatar TEXT,
    nickname TEXT,
    games_played INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    coins INTEGER DEFAULT 1000,
    is_banned BOOLEAN DEFAULT 0,
    last_seen TIMESTAMP
);

-- Matches Table
CREATE TABLE IF NOT EXISTS matches (
    match_id TEXT PRIMARY KEY,
    created_at TIMESTAMP,
    ended_at TIMESTAMP,
    players_json TEXT,
    winner_id TEXT,
    metadata TEXT
);

-- Friends Table
CREATE TABLE IF NOT EXISTS friends (
    user_id TEXT,
    friend_id TEXT,
    status TEXT, -- 'pending', 'accepted'
    created_at TIMESTAMP,
    PRIMARY KEY (user_id, friend_id)
);

-- Challenges Table
CREATE TABLE IF NOT EXISTS challenges (
    id TEXT PRIMARY KEY,
    title TEXT,
    description TEXT,
    goal INTEGER,
    reward INTEGER,
    type TEXT
);

-- User Challenges Table (Progress)
CREATE TABLE IF NOT EXISTS user_challenges (
    user_id TEXT,
    challenge_id TEXT,
    current INTEGER DEFAULT 0,
    is_claimed BOOLEAN DEFAULT 0,
    updated_at TIMESTAMP,
    PRIMARY KEY (user_id, challenge_id)
);
