set -e

WG_DIR="/etc/wireguard"
clear
echo "=============================="
echo "GLMBX WIREGUARD PEER-REMOVER"
echo "=============================="
echo ""
# List available tunnels
echo "Available tunnels:"
ls $WG_DIR | grep '\.conf$' | sed 's/\.conf//'
echo "Enter the name of the tunnel from which you want to remove a peer:"
read TUNNEL_NAME

WG_CONF="$WG_DIR/${TUNNEL_NAME}.conf"
PEERS_DIR="./peers/${TUNNEL_NAME}"

if [[ ! -f $WG_CONF ]]; then
    echo "Tunnel $TUNNEL_NAME not found in $WG_DIR"
    exit 1
fi

if [[ ! -d $PEERS_DIR ]]; then
    echo "No peers found for tunnel $TUNNEL_NAME"
    exit 0
fi

# List available peers
echo "Available peers:"
ls $PEERS_DIR | sed 's/\.conf//'

echo "Enter the name of the peer to remove:"
read PEER_NAME

PEER_FILE="$PEERS_DIR/${PEER_NAME}.conf"

if [[ ! -f $PEER_FILE ]]; then
    echo "Peer $PEER_NAME does not exist."
    exit 1
fi

# Remove the peer's config file
rm -f $PEER_FILE
echo "Peer configuration file $PEER_FILE removed."

# Optional: remove the peer section from the tunnel config if present
# We search for the peer's public key in the tunnel conf
PEER_PUBKEY=$(grep -A2 "^\[Peer\]" $PEER_FILE 2>/dev/null | grep "PublicKey" | cut -d'=' -f2 | tr -d ' ')

if [[ -n "$PEER_PUBKEY" ]]; then
    # Remove the section in the tunnel conf
    awk -v key="$PEER_PUBKEY" '
    BEGIN {print_flag=1}
    /^\[Peer\]/ {peer_block=0}
    $0 ~ key {print_flag=0; peer_block=1}
    peer_block && /^\[Peer\]/ {print_flag=1; peer_block=0}
    {if(print_flag) print}
    ' $WG_CONF > "${WG_CONF}.tmp" && mv "${WG_CONF}.tmp" $WG_CONF

    echo "Peer $PEER_NAME removed from tunnel configuration $WG_CONF"
else
    echo "Peer public key not found in tunnel configuration. Manual removal may be needed."
fi
