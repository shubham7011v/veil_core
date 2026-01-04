# Server & ngrok Troubleshooting Guide

If you see a **502 Bad Gateway**, **Port already in use**, or your devices aren't connecting, follow these steps to reset everything.

---

## 1. Clear "Ghost" Processes
Sometimes the server or ngrok keeps running in the background even after you close the terminal.

Run these in **PowerShell**:

```powershell
# 1. Kill any existing Go server sessions
taskkill /F /IM veil_server.exe /T 2>$null

# 2. Kill any existing ngrok sessions
taskkill /F /IM ngrok.exe /T 2>$null

# 3. Double check port 8080 is free
# If this returns anything, copy the PID (last number) and run: taskkill /F /PID [NUMBER]
netstat -ano | findstr :8080
```

---

## 2. Start the Go Server (Terminal 1)
Make sure the server is running on the correct port before starting ngrok.

```powershell
cd c:\Users\u32n08\Documents\veil_core\server
go run .
```
**Verify:** Look for the log: `Veil Server listening on :8080`.

---

## 3. Start ngrok (Terminal 2)
You MUST specify port **8080**. If you just type `ngrok http 80`, it will fail because your server is on 8080.

```powershell
ngrok http 8080
```

**Verify:**
1. Look for `Forwarding` URL (e.g., `https://rebelliously-unforgone-mandie.ngrok-free.dev`).
2. Open [http://localhost:4040](http://localhost:4040) in your browser. 
3. Click **Tunnels** -> **Inspect**. It should show `http://localhost:8080` as the target.

---

## 4. Common Fixes Summary

| Symptom | Probable Cause | Fix |
|:---|:---|:---|
| **502 Bad Gateway** | ngrok is pointing to the wrong port | Restart ngrok with `ngrok http 8080` |
| **Port Bind Error** | Old server still running | Run `taskkill /F /IM veil_server.exe` |
| **Connection Timed Out** | Windows Firewall blocking | Click 'Allow' on the Windows Security popup |
| **1/4 to 0/4 Jump** | Room state mismatch | Refresh the app; server now auto-cleans old slots |

---

## 5. Wireless Testing Cheat Sheet
To test with two devices wirelessly:
1. Ensure both phones are on the same Wi-Fi as your PC.
2. In the Flutter app, use the **ngrok URL** provided in step 3.
3. Use the **Long-Press Bypass** on the "Enter Court" screen to skip login for faster testing.
