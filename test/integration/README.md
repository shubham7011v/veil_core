# Client-Server Integration Test Runner

This script helps run end-to-end integration tests between the Flutter client and Go server.

## Prerequisites

1. **Go server** must be running on `localhost:8080`
2. **Flutter dependencies** installed

## Running Tests

### Start the Server

Open a terminal and start the server:

```bash
cd server
go run cmd/server/main.go
```

### Run Server-Side Integration Tests

These tests simulate multiple WebSocket clients connecting to the server:

```bash
cd server
go test ./room -v -run "TestClientServerSync|TestReconnectionSync|TestMultiClientStateConsistency|TestChatMessageSync|TestGameActionPropagation"
```

**Expected Output:**
```
=== RUN   TestClientServerSync
=== RUN   TestClientServerSync/Message_Broadcast_Sync
✅ Both clients successfully synchronized
--- PASS: TestClientServerSync/Message_Broadcast_Sync
=== RUN   TestClientServerSync/Game_Action_Sync
✅ Client 1 received game start
✅ Client 2 received game start
--- PASS: TestClientServerSync/Game_Action_Sync
--- PASS: TestClientServerSync
```

### Run Client-Side Integration Tests

> **Note:** These tests require the server to be running!

```bash
# Run all integration tests
flutter test test/integration/client_server_sync_test.dart

# Run with verbose output
flutter test test/integration/client_server_sync_test.dart -r expanded
```

**Test Status:**
- Most tests are marked as `skip: 'Requires running server'` to avoid CI/CD failures
- To run them, remove the `skip` parameter and ensure server is running

## Manual Testing

If automated tests fail, you can manually verify synchronization:

1. **Terminal 1:** Start server
   ```bash
   cd server && go run cmd/server/main.go
   ```

2. **Terminal 2:** Run server tests
   ```bash
   cd server && go test ./room -v -run TestClientServerSync
   ```

3. **Terminal 3:** Run Flutter app and connect
   ```bash
   flutter run
   # Tap "Play" to join matchmaking
   # Observe console logs for WebSocket messages
   ```

## What These Tests Verify

### Server-Side Tests (`client_server_sync_test.go`)

1. **Message Broadcast Sync**
   - Two clients join same room
   - Both receive synchronized GAME_STATE updates
   - Verifies broadcast mechanism works

2. **Game Action Sync**
   - Clients create/join private room
   - Game starts
   - Both receive synchronized game start event
   - Verifies game state propagation

3. **Reconnection Sync**
   - Client disconnects mid-session
   - Reconnects with same credentials
   - Receives current game state
   - Verifies state recovery

4. **Multi-Client State Consistency**
   - 3 clients join matchmaking
   - All receive state updates
   - Participant counts match across all clients
   - Verifies eventual consistency

5. **Chat Message Sync**
   - Two clients in private room
   - One sends chat message
   - Other receives it immediately
   - Verifies real-time message delivery

6. **Game Action Propagation**
   - Play cards, pass, challenge actions
   - All clients receive action broadcasts
   - Verifies action sync infrastructure

### Client-Side Tests (`client_server_sync_test.dart`)

1. **Connection Test**
   - Flutter client connects to Go server
   - Receives AUTH_OK
   - Verifies WebSocket handshake

2. **Room Sync Test**
   - Two Flutter clients connect
   - Both join same room
   - Verify synchronized state updates

3. **Reconnection Test**
   - Client disconnects
   - Auto-reconnects
   - Resumes previous state

4. **Chat Sync Test**
   - Send chat from client 1
   - Receive on client 2
   - Verify real-time chat

5. **Game State Test**
   - Join matchmaking
   - Receive state updates
   - Verify participant list

6. **Network Interruption Test**
   - Simulate network loss
   - Verify graceful reconnection

## Troubleshooting

### "Server not responding"
- Ensure server is running on `localhost:8080`
- Check firewall settings
- Verify no other service using port 8080

### "Connection timeout"
- Server might be starting up - wait a few seconds
- Check server logs for errors
- Ensure database is initialized correctly

### "Auth failed"
- Server running in insecure mode accepts any token
- Check AUTH message format in logs

### Tests skip automatically
- Remove `skip` parameter from test definitions
- Ensure server is running first

## CI/CD Integration

To run these tests in CI/CD:

1. Start server in background:
   ```bash
   cd server && go run cmd/server/main.go &
   SERVER_PID=$!
   sleep 5  # Wait for server to start
   ```

2. Run tests:
   ```bash
   go test ./room -v -run TestClientServerSync
   flutter test test/integration/client_server_sync_test.dart
   ```

3. Cleanup:
   ```bash
   kill $SERVER_PID
   ```

## Next Steps

After verifying sync:
- [ ] Add more game action scenarios
- [ ] Test with bots
- [ ] Test reconnection during active game
- [ ] Test network switches (WiFi → Mobile)
- [ ] Add performance/latency tests
