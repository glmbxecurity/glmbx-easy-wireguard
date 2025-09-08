#!/bin/bash
set -e

WG_DIR="/etc/wireguard"

clear
echo "=============================="
echo "GLMBX WIREGUARD PEER-CREATOR"
echo "=============================="

# List available tunnels
echo "Available tunnels:"
ls $WG_DIR | grep '\.conf$' | sed 's/\.conf//'
echo "Enter the name of the tunnel to which you want to add peers:"
read TUNNEL_NAME

WG_CONF="$WG_DIR/${TUNNEL_NAME}.conf"

if [[ ! -f $WG_CONF ]]; then
    echo "Tunnel $TUNNEL_NAME not found in $WG_DIR"
    exit 1
fi

# Read tunnel configuration from its .conf
SERVER_PUBKEY=$(grep "^ServerPublicKey" $WG_CONF | cut -d'=' -f2 | tr -d ' ')
ENDPOINT=$(grep "^Endpoint" $WG_CONF | cut -d'=' -f2 | tr -d ' ')
PORT=$(grep "^ListenPort" $WG_CONF | cut -d'=' -f2 | tr -d ' ')
DNS=$(grep "^DNS" $WG_CONF | cut -d'=' -f2 | tr -d ' ')
TUNNEL_NET=$(grep "^TUNNEL_NET" $WG_CONF | cut -d'=' -f2 | tr -d ' ')

# Peers folder for this tunnel
PEERS_DIR="./peers/${TUNNEL_NAME}"
mkdir -p $PEERS_DIR

while true; do
    echo ""
    echo "Peer name:"
    read PEER_NAME

    # Ask if all traffic should go through the tunnel
    echo "Do you want to route all traffic through the tunnel? (y/n)"
    read ROUTE_ALL
    if [[ "$ROUTE_ALL" == "y" ]]; then
        ALLOWED_IPS="0.0.0.0/0"
    else
        echo "Enter the networks to route (e.g., 192.168.1.0/24,10.0.0.0/8):"
        read ALLOWED_IPS
    fi

    # Ask for DNS
    echo "Do you want to use the default DNS ($DNS)? (y/n)"
    read USE_DEFAULT_DNS
    if [[ "$USE_DEFAULT_DNS" == "y" ]]; then
        DNS_FINAL=$DNS
    else
        echo "Enter the DNS you want to use:"
        read DNS_FINAL
    fi

    # Generate peer keys
    PEER_PRIVKEY=$(wg genkey)
    PEER_PUBKEY=$(echo $PEER_PRIVKEY | wg pubkey)

    # Automatically calculate IP within the tunnel subnet
    TUNNEL_BASE=$(echo $TUNNEL_NET | sed 's#/24##' | awk -F. '{print $1 "." $2 "." $3 "."}')
    OCTET=$(ls $PEERS_DIR | wc -l)
    PEER_IP="$TUNNEL_BASE$((OCTET+2))"

    # Create peer configuration file
    PEER_FILE="$PEERS_DIR/${PEER_NAME}.conf"
    cat > $PEER_FILE <<EOF
[Interface]
PrivateKey = $PEER_PRIVKEY
Address = $PEER_IP/24
DNS = $DNS_FINAL

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $ENDPOINT:$PORT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
EOF

    echo "Peer $PEER_NAME created at $PEER_FILE"

    # Add the peer to the server tunnel configuration
    cat >> $WG_CONF <<EOF

# Peer: $PEER_NAME
[Peer]
PublicKey = $PEER_PUBKEY
AllowedIPs = $PEER_IP/32
EOF

    echo "Peer $PEER_NAME added to the server tunnel configuration $WG_CONF"

    # Ask if the user wants to add another peer
    echo ""
    echo "Do you want to add another peer to $TUNNEL_NAME? (y/n)"
    read ADD_ANOTHER
    if [[ "$ADD_ANOTHER" != "y" ]]; then
        echo "Finished adding peers."
        break
    fi
done
