# glmbx-easy-wireguard

**glmbx-easy-wireguard** is a lightweight set of scripts to easily manage WireGuard VPN tunnels and clients. It simplifies the process of creating WireGuard tunnels, adding or removing clients, and maintaining proper configuration, making it ideal for both personal and small-scale professional use.

---

## Features

* **Create a WireGuard tunnel** with a simple configuration file.
* **Add multiple clients (peers)** to a tunnel with automatic IP assignment, DNS configuration, and optional full traffic routing.
* **Remove clients** cleanly from both the server configuration and individual peer files.
* Fully modular and easy to use, no advanced WireGuard knowledge required.
* Supports multiple tunnels on the same server.

---

## Scripts

The project contains **three main scripts**:

### 1. `create_tunnel.sh`

* Reads server and tunnel parameters from `config.txt`.
* Generates server private/public keys.
* Creates the WireGuard tunnel configuration in `/etc/wireguard/<tunnel>.conf`.
* Optionally prompts to add clients immediately after creating the tunnel.
* Example `config.txt` structure:

```ini
TUNNEL_NAME=glmbx
ENDPOINT=vpn.example.com
PORT=51820
TUNNEL_NET=10.10.0.0/24
SERVER_IP=10.10.0.1
DNS=1.1.1.1
```

### 2. `add_peer.sh`

* Adds a new client (peer) to an existing tunnel.
* Automatically generates client private/public keys.
* Calculates an available IP within the tunnel subnet.
* Creates the peer configuration file under `./peers/<tunnel>/<peer>.conf`.
* Appends the peer section to the server tunnel `.conf`.
* Supports custom DNS and optional full traffic routing.
* Can add multiple peers in a single run.

### 3. `remove_peer.sh`

* Removes a client (peer) from a tunnel.
* Deletes both the peer configuration file (`./peers/<tunnel>/<peer>.conf`) and its entry in the server `.conf`.
* Ensures clean removal without leaving orphaned entries.

---

## How to Use

1. **Edit the configuration file** (`config.txt`) with your tunnel information.

2. **Create a tunnel**:

```bash
sudo bash create_tunnel.sh
```

* The script will display a summary of the tunnel configuration for confirmation.
* You can choose to add clients immediately after creation.

3. **Add clients**:

```bash
sudo bash add_peer.sh
```

* Select the tunnel and provide client details.
* Choose whether to route all traffic through the VPN or only specific subnets.
* Configure DNS for each client.

4. **Remove clients**:

```bash
sudo bash remove_peer.sh
```

* Select the tunnel and the client to remove.
* The client configuration file and server configuration entry will be removed automatically.

5. **Start the tunnel**:

```bash
sudo wg-quick up <TUNNEL_NAME>
```

6. **Stop the tunnel**:

```bash
sudo wg-quick down <TUNNEL_NAME>
```

---

## Folder Structure

```
.
├── create_tunnel.sh      # Script to create a new WireGuard tunnel
├── add_peer.sh           # Script to add clients to a tunnel
├── remove_peer.sh        # Script to remove clients from a tunnel
├── config.txt            # Tunnel configuration template
└── peers/
    └── <tunnel>/
        └── <peer>.conf  # Individual client configurations
```

---

## Notes

* Keys are generated automatically using `wg genkey`.
* Ensure `/etc/wireguard` is writable by the user running the scripts.
* Make sure `WireGuard` is installed on the system.
