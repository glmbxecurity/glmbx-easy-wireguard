# glmbx-easy-wireguard 🛡️

**glmbx-easy-wireguard** is a lightweight set of Bash scripts to easily manage WireGuard VPN tunnels and clients on Linux (optimized for Alpine/Debian).

It simplifies the process of creating WireGuard tunnels, handling **NAT/Firewall rules** automatically, adding/removing clients with **Hot-Reload** (no downtime), and generating QR codes.

![image](https://raw.githubusercontent.com/glmbxecurity/glmbx-easy-wireguard/refs/heads/main/glmbx-easy-wireguard.PNG)

---

## Features ✨

* **Auto NAT & Routing:** Automatically configures `iptables` and IP Forwarding to allow clients to access the Internet.
* **Zero Downtime:** Add or remove clients without restarting the interface (uses `wg syncconf`).
* **Smart Keepalive:** Automatically configures `PersistentKeepalive` to maintain connections on unstable networks (4G/5G).
* **QR Code Generator:** Display connection QR codes directly in the terminal.
* **Security:** Optional Preshared Keys (PSK) and randomized keys for every peer.

---

## Scripts 📂

### 1. `create_tunnel.sh`
* Reads parameters from `config.txt`.
* Creates the interface config with **IP Masquerading (NAT)** rules.
* Sets up system persistence (OpenRC/Systemd).

### 2. `add_peer.sh`
* Adds a new client to an existing tunnel.
* Calculates the next available IP automatically.
* Applies changes instantly (**Hot-Reload**) without disconnecting other users.
* Generates a QR code at the end.

### 3. `remove_peer.sh`
* Cleanly removes a client from the config and deletes their file.
* Updates the live interface instantly.

### 4. `qr_tunnel_generator.sh`
* Scans for existing client configurations and generates a QR code on demand.

---

## How to Use 🚀

1. **Install Dependencies**:
   ```bash
   # Alpine
   apk add bash wireguard-tools libqrencode
   # Debian/Ubuntu
   apt install wireguard qrencode
   ```

2. **Edit Configuration**:
   Modify `config.txt` with your server's Public IP and desired settings.

3. **Create Tunnel**:
   ```bash
   ./create_tunnel.sh
   ```
   *Follow the prompts to enable Internet access (NAT) via your main interface (e.g., eth0).*

4. **Add Clients**:
   ```bash
   ./add_peer.sh
   ```

5. **Show QR Codes later**:
   ```bash
   ./qr_tunnel_generator.sh
   ```

---

## Folder Structure

```
.
├── create_tunnel.sh      # Setup script
├── add_peer.sh           # Client creator (Hot-reload)
├── remove_peer.sh        # Client remover (Hot-reload)
├── qr_tunnel_generator.sh# QR Helper
├── config.txt            # Settings template
└── peers/
    └── <tunnel_name>/
        └── <peer_name>.conf  # Generated client configs
```

## Notes
* Ensure you run these scripts as **root**.
* If you are behind a NAT, remember to port-forward the UDP port (default 51820) on your router.
