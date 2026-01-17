// Package db provides database operations for the Veil game server.
//
// # Overview
//
// This package handles all persistent storage operations using SQLite, including:
//   - User authentication and profile management
//   - Game statistics and leaderboards
//   - Match history tracking
//   - Friend relationships
//   - Daily challenges
//   - Coin transactions
//
// # Database Schema
//
// Main tables:
//   - users: Player profiles, authentication, and stats
//   - matches: Historical game records
//   - friends: Social relationships between players
//   - daily_challenges: Challenge definitions and player progress
//
// # Buffered Updates
//
// For performance, coin updates are buffered and committed asynchronously:
//   - BufferCoinUpdate: Queue a coin change
//   - FlushCoinUpdates: Force immediate commit
//   - AutoFlush: Background goroutine commits every 5 seconds
//
// # Thread Safety
//
// All database operations are thread-safe. The package uses connection pooling
// and proper locking for buffered updates.
//
// # Error Handling
//
// Database errors are logged but generally not fatal. Failed transactions are
// retried automatically where appropriate.
package db
