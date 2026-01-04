# Manual Testing Guide - Go WebSocket Server

## Prerequisites

- [x] Go installed (version 1.25+)
- [x] Flutter installed
- [ ] ngrok installed (for remote testing)
- [ ] Firebase project configured

---

## Part 1: Local Server Testing (Single Device)

### Step 1: Start the Go Server

```powershell
# Navigate to server directory
cd c:\Users\u32n08\Documents\veil_core\server

# Run the server
go run .
```

**Expected Output:**
```
2026/01/04 11:07:22 Veil Server listening on :8080
```

✅ Server is now running on `ws://localhost:8080/ws`

---

### Step 2: Test Server with WebSocket Client Tool

**Option A: Using Browser Console**

1. Open Chrome/Edge
2. Navigate to: `http://localhost:8080`
3. Press `F12` to open DevTools
4. Go to **Console** tab
5. Paste this code:

```javascript
const ws = new WebSocket('ws://localhost:8080/ws');

ws.onopen = () => {
  console.log('✅ Connected!');
  
  // Send AUTH message
  ws.send(JSON.stringify({
    type: 'AUTH',
    data: { token: 'test_token_123' }
  }));
};

ws.onmessage = (event) => {
  console.log('📩 Received:', JSON.parse(event.data));
};

ws.onerror = (error) => {
  console.error('❌ Error:', error);
};

ws.onclose = () => {
  console.log('🔌 Disconnected');
};
```

**Expected Output:**
```
✅ Connected!
📩 Received: {type: "AUTH_OK", data: {playerId: "user_test_token_123"}}
```

**Option B: Using Postman (if installed)**

1. Open Postman
2. Create New → WebSocket Request
3. URL: `ws://localhost:8080/ws`
4. Click **Connect**
5. Send message:
   ```json
   {"type": "AUTH", "data": {"token": "test_123"}}
   ```

---

### Step 3: Test Full Game Flow (2 Clients)

**Terminal 1 - Keep Server Running:**
```powershell
cd server
go run .
```

**Terminal 2 - Run Integration Test:**
```powershell
cd server
go test -v
```

**Expected Output:**
```
=== RUN   TestGameFlow
    main_test.go:47: State A: map[...]
    main_test.go:48: State B: map[...]
    main_test.go:56: Active Player is: user_A
    main_test.go:79: Playing card: seven_of_hearts (Rank: seven)
    main_test.go:97: Passive player sending CHALLENGE...
    main_test.go:102: Challenge resolved successfully
--- PASS: TestGameFlow (0.04s)
PASS
```

✅ Server logic is working correctly!

---

## Part 2: Flutter App Connection (Same Machine)

### Step 1: Modify Lobby Screen to Use Online Mode

**File:** `lib/features/lobby/ui/lobby_screen.dart`

Add a test button temporarily:

```dart
// In your lobby screen build method, add:
ElevatedButton(
  onPressed: () async {
    // Get Firebase token
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ Not logged in');
      return;
    }
    
    final token = await user.getIdToken();
    
    // Create online handler
    final handler = sl.createSessionHandler(online: true) as WebSocketSessionHandler;
    
    // Connect
    await handler.connect('ws://localhost:8080/ws', token!);
    
    print('✅ Connected to server!');
  },
  child: Text('🧪 Test WebSocket'),
),
```

### Step 2: Run Flutter App

```powershell
flutter run
```

1. Launch app on emulator/device
2. Login with Google/Apple
3. Click "🧪 Test WebSocket" button
4. Check logs

**Expected Logs:**
```
✅ Connected to server!
Auth successful: {playerId: uid_...}
```

---

## Part 3: Multi-Device Testing with ngrok

### Step 1: Install ngrok

**Download:** https://ngrok.com/download

```powershell
# Unzip to a folder, add to PATH
# Or use chocolatey:
choco install ngrok
```

### Step 2:  Sign Up & Auth Token

1. Create free account: https://dashboard.ngrok.com/signup
2. Get auth token: https://dashboard.ngrok.com/get-started/your-authtoken
3. Configure:

```powershell
ngrok config add-authtoken YOUR_TOKEN_HERE
```

### Step 3: Start Tunnel

**Terminal 1 - Go Server:**
```powershell
cd server
go run .
```

**Terminal 2 - ngrok:**
```powershell
ngrok http 8080
```

**Expected Output:**
```
Session Status                online
Account                       your@email.com
Forwarding                    https://abc123.ngrok-free.app -> http://localhost:8080
```

✅ Copy the **https** URL (e.g., `https://abc123.ngrok-free.app`)

### Step 4: Update Flutter App

Change WebSocket URL:

```dart
// NOTE: Use WSS (secure) for ngrok HTTPS URLs
await handler.connect('wss://abc123.ngrok-free.app/ws', token!);
```

### Step 5: Test on Multiple Devices

1. **Device 1:** Android Emulator
   ```powershell
   flutter run
   ```

2. **Device 2:** Desktop App
   ```powershell
   flutter run -d windows
   ```

3. **Device 3:** Real Phone
   - Build APK: `flutter build apk`
   - Install on phone
   - Update server URL in code to ngrok URL

---

## Part 4: Verifying Game Flow

### Checklist

- [ ] **Auth Flow:**
  - Client sends `AUTH` with Firebase token
  - Server responds `AUTH_OK` with playerId
  
- [ ] **Room Join:**
  - Client sends `JOIN_ROOM`
  - Server adds player to room
  - When 2 players join, game auto-starts
  - Clients receive `GAME_STATE` with phase: `thinking`

- [ ] **Play Cards:**
  - Active player sends `PLAY_CARDS` with cardIds and declaredRank
  - Server validates turn
  - All clients receive updated `GAME_STATE` with phase: `challenging`

- [ ] **Challenge:**
  - Next player sends `CHALLENGE`
  - Server checks bluff
  - Loser gets pile
  - All clients receive `GAME_STATE` with phase: `thinking`

- [ ] **Pass:**
  - Player sends `PASS`
  - Server advances turn
  - If all pass, pile discarded

- [ ] **Win Condition:**
  - Player reaches 0 cards
  - Server broadcasts `GAME_STATE` with winnerId

---

## Part 5: Debugging

### Server Logs

Watch server terminal for:
```
2026/01/04 11:07:22 Veil Server listening on :8080
2026/01/04 11:07:30 New Connection Registered
2026/01/04 11:07:30 Msg Type: AUTH from Client user_abc
2026/01/04 11:07:30 Msg Type: JOIN_ROOM from Client user_abc
2026/01/04 11:07:30 Client joined Room demo
```

### Flutter Logs

Check for:
```dart
print('WebSocket connected');
print('Auth successful: $data');
print('Received GAME_STATE: $stateData');
```

### Common Issues

| Issue | Solution |
|:------|:---------|
| `Connection refused` | Make sure server is running (`go run .`) |
| `WebSocket closed immediately` | Check firewall/antivirus blocking port 8080 |
| `AUTH_FAIL` | Firebase token expired - re-login |
| `No GAME_STATE received` | Check server logs for errors |
| ngrok "tunnel not found" | Restart ngrok, update URL in app |

---

## Part 6: Production-Like Test (Optional)

### Using systemd (Linux-style on WSL)

If you have WSL2 installed:

```bash
# Build binary
cd server
GOOS=linux GOARCH=amd64 go build -o veil_server

# Copy to WSL
wsl
mkdir ~/veil_server
# Copy binary to WSL

# Create systemd service
sudo nano /etc/systemd/system/veil-server.service
```

**Service File:**
```ini
[Unit]
Description=Veil Game Server
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/home/youruser/veil_server
ExecStart=/home/youruser/veil_server/veil_server
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable veil-server
sudo systemctl start veil-server
sudo systemctl status veil-server
```

---

## Quick Reference

### Server Commands
```powershell
# Run server
cd server && go run .

# Run tests
cd server && go test -v

# Build binary
cd server && go build

# Run binary
cd server && .\veil_server.exe
```

### ngrok Commands
```powershell
# Start tunnel
ngrok http 8080

# With custom domain (paid)
ngrok http 8080 --domain=your-subdomain.ngrok-free.app

# View active tunnels
ngrok tunnels list
```

### Flutter Commands
```powershell
# Run on emulator
flutter run

# Run on Windows
flutter run -d windows

# Build APK for testing
flutter build apk --debug

# View logs
flutter logs
```

---

## Success Criteria

✅ **Phase 1 Complete When:**
- [ ] 2 players connect simultaneously
- [ ] Game auto-starts
- [ ] Players can see each other's card counts
- [ ] Player A plays card successfully
- [ ] Player B challenges successfully
- [ ] Pile transfers correctly
- [ ] Game continues after challenge
- [ ] Full game reaches winner state

🎉 Ready for Phase 2 (Closed Beta on Vultr)!
