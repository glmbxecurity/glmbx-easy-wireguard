#!/bin/bash
clear
set -e

CONFIG_FILE="config.txt"

if [[ ! -f $CONFIG_FILE ]]; then
    echo "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

# Load tunnel configuration
source $CONFIG_FILE

# Show summary of the configuration
echo "=============================="
echo "GLMBX WIREGUARD TUNNEL-CREATOR"
echo "=============================="
echo ""
echo "Tunnel creation summary:"
echo "---------------------------"
echo "Tunnel name      : $TUNNEL_NAME"
echo "Endpoint         : $ENDPOINT"
echo "Tunnel port      : $PORT"
echo "Tunnel network   : $TUNNEL_NET"
echo "Server IP        : $SERVER_IP"
echo "DNS for clients  : $DNS"
echo "---------------------------"

# User confirmation
echo "Do you confirm the tunnel creation with these settings? (y/n)"
read CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Tunnel creation cancelled."
    exit 0
fi

WG_CONF="/etc/wireguard/${TUNNEL_NAME}.conf"
PRIV_FILE="/etc/wireguard/${TUNNEL_NAME}-privkey"
PUB_FILE="/etc/wireguard/${TUNNEL_NAME}-pubkey"

# Generate server keys
SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo $SERVER_PRIVKEY | wg pubkey)

# Save keys to files
echo "$SERVER_PRIVKEY" > "$PRIV_FILE"
chmod 600 "$PRIV_FILE"
echo "$SERVER_PUBKEY" > "$PUB_FILE"
chmod 644 "$PUB_FILE"

# Create the tunnel configuration file (without ServerPublicKey)
cat > $WG_CONF <<EOF
[Interface]
PrivateKey = $SERVER_PRIVKEY
Address = $SERVER_IP
ListenPort = $PORT
DNS = $DNS
#TUNNEL_NET = $TUNNEL_NET  # for reference only
EOF

echo "Tunnel $TUNNEL_NAME created at $WG_CONF"
echo "Server private key saved at $PRIV_FILE"
echo "Server public key saved at $PUB_FILE"
echo "Use 'wg-quick up $TUNNEL_NAME' to activate it"

# Ask if the user wants to create clients now
echo "Do you want to create clients now? (y/n)"
read CREATE_CLIENTS

if [[ "$CREATE_CLIENTS" == "y" ]]; then
    ./add_peer.sh
fi
