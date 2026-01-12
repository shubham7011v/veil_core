---
description: "How to monitor server logs via SSH"
---

1. **SSH into your server:**
   ```bash
   ssh root@<your-server-ip>
   ```

2. **Check if running via Docker (Most Likely):**
   ```bash
   docker ps
   ```

3. **Tail Logs:**
   - **If Docker:**
     ```bash
     docker logs -f veil_server_1 --tail 100
     # OR just
     docker logs -f $(docker ps -qf "name=veil")
     ```
   - **If Systemd/Binary:**
     ```bash
     journalctl -u veil-server -f
     ```
   - **If Screen/Tmux:**
     ```bash
     screen -r
     # OR
     tmux attach
     ```

4. **Grep for Errors:**
   ```bash
   docker logs veil_server_1 2>&1 | grep -i "error\|panic"
   ```
