#!/bin/bash
set -e
WG_DIR="/etc/wireguard"

clear
echo "=============================="
echo "GLMBX WIREGUARD PEER-REMOVER"
echo "=============================="
echo ""

# List available tunnels (numerically selectable)
TUNNELS=($(ls "$WG_DIR" | grep '\.conf$' | sed 's/\.conf//'))
if [ ${#TUNNELS[@]} -eq 0 ]; then
    echo "No WireGuard tunnels found in $WG_DIR"
    exit 1
fi

echo "Available tunnels:"
for i in "${!TUNNELS[@]}"; do
    echo "  $((i+1))) ${TUNNELS[$i]}"
done

while true; do
    read -p "Select the tunnel number: " TUNNEL_INDEX
    if [[ "$TUNNEL_INDEX" -ge 1 ]] 2>/dev/null && [[ "$TUNNEL_INDEX" -le "${#TUNNELS[@]}" ]]; then
        TUNNEL_NAME="${TUNNELS[$((TUNNEL_INDEX-1))]}"
        break
    else
        echo "Invalid selection. Try again."
    fi
done

WG_CONF="$WG_DIR/${TUNNEL_NAME}.conf"
PEERS_DIR="./peers/${TUNNEL_NAME}"

if [[ ! -f "$WG_CONF" ]]; then
    echo "Tunnel $TUNNEL_NAME not found in $WG_DIR"
    exit 1
fi

if [[ ! -d "$PEERS_DIR" ]]; then
    echo "No peers found for tunnel $TUNNEL_NAME"
    exit 0
fi

# List available peers (numerically selectable)
PEERS=($(ls "$PEERS_DIR" | sed 's/\.conf//'))
if [ ${#PEERS[@]} -eq 0 ]; then
    echo "No peers found for tunnel $TUNNEL_NAME"
    exit 0
fi

echo "Available peers:"
for i in "${!PEERS[@]}"; do
    echo "  $((i+1))) ${PEERS[$i]}"
done

while true; do
    read -p "Select the peer number to remove: " PEER_INDEX
    if [[ "$PEER_INDEX" -ge 1 ]] 2>/dev/null && [[ "$PEER_INDEX" -le "${#PEERS[@]}" ]]; then
        PEER_NAME="${PEERS[$((PEER_INDEX-1))]}"
        break
    else
        echo "Invalid selection. Try again."
    fi
done

PEER_FILE="$PEERS_DIR/${PEER_NAME}.conf"

if [[ ! -f "$PEER_FILE" ]]; then
    echo "Peer $PEER_NAME does not exist."
    exit 1
fi

# Read the peer's public key before deleting
PEER_PUBKEY=$(grep "PublicKey" "$PEER_FILE" | cut -d'=' -f2 | tr -d ' ')
PEER_IP=$(grep "Address" "$PEER_FILE" | cut -d'=' -f2 | tr -d ' ')

echo ""
echo "Peer information to remove:"
echo "  Name: $PEER_NAME"
echo "  Public Key: $PEER_PUBKEY"
echo "  IP Address: $PEER_IP"
echo ""

read -p "Are you sure you want to remove this peer? (y/n) " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Peer removal cancelled."
    exit 0
fi

# Remove peer section from tunnel config
awk -v name="$PEER_NAME" '
    BEGIN { skip=0 }
    /^# Peer: / {
        if ($0 == "# Peer: " name) { skip=1; next }
        else { skip=0 }
    }
    {
        if (skip==0) print
    }
' "$WG_CONF" > "${WG_CONF}.tmp" && mv "${WG_CONF}.tmp" "$WG_CONF"
echo "Peer $PEER_NAME removed from tunnel configuration $WG_CONF"

# Remove peer config file
rm -f "$PEER_FILE"
echo "Peer configuration file $PEER_FILE removed."

echo ""
echo "Peer $PEER_NAME has been successfully removed!"
echo ""

# Restart the tunnel
echo "Reiniciando el túnel $TUNNEL_NAME..."
wg-quick down "$TUNNEL_NAME"
wg-quick up "$TUNNEL_NAME"
echo "Túnel $TUNNEL_NAME reiniciado con éxito."
