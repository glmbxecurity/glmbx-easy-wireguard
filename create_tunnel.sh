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

# Ask about forwarding and internet access
echo ""
echo "Do you want to enable IP forwarding and allow access to internet/other networks through the tunnel? (y/n)"
read ENABLE_FORWARDING

# If forwarding is enabled, ask for the output interface
if [[ "$ENABLE_FORWARDING" == "y" ]]; then
    echo ""
    echo "Available network interfaces:"
    ip -br link show | grep -v "^lo" | awk '{print "  - " $1}'
    echo ""
    echo "Enter the network interface for internet/network access (e.g., eth0, ens3, wg0):"
    read MAIN_IFACE
    
    if [[ -z "$MAIN_IFACE" ]]; then
        echo "Error: No interface specified. Tunnel creation cancelled."
        exit 1
    fi
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

# Create the tunnel configuration file
cat > $WG_CONF <<EOF
[Interface]
PrivateKey = $SERVER_PRIVKEY
Address = $SERVER_IP
ListenPort = $PORT
DNS = $DNS
#TUNNEL_NET = $TUNNEL_NET  # for reference only

EOF

# Add forwarding and iptables rules if requested
if [[ "$ENABLE_FORWARDING" == "y" ]]; then
    cat >> $WG_CONF <<EOF
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i ${TUNNEL_NAME} -j ACCEPT
PostUp = iptables -A FORWARD -o ${TUNNEL_NAME} -m state --state RELATED,ESTABLISHED -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -s $TUNNEL_NET -o $MAIN_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i ${TUNNEL_NAME} -j ACCEPT
PostDown = iptables -D FORWARD -o ${TUNNEL_NAME} -m state --state RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s $TUNNEL_NET -o $MAIN_IFACE -j MASQUERADE

EOF

    echo ""
    echo "IP forwarding and NAT rules added to configuration."
    echo "Output interface configured: $MAIN_IFACE"
    
    # Optionally make IP forwarding permanent
    echo ""
    echo "Do you want to make IP forwarding permanent in /etc/sysctl.conf? (y/n)"
    read MAKE_PERMANENT
    
    if [[ "$MAKE_PERMANENT" == "y" ]]; then
        if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
            echo "IP forwarding enabled permanently in /etc/sysctl.conf"
        else
            echo "IP forwarding already enabled in /etc/sysctl.conf"
        fi
    fi
fi

echo ""
echo "=============================="
echo "Tunnel $TUNNEL_NAME created successfully!"
echo "=============================="
echo "Configuration file: $WG_CONF"
echo "Server private key: $PRIV_FILE"
echo "Server public key:  $PUB_FILE"
echo ""
echo "To activate the tunnel, run:"
echo "  wg-quick up $TUNNEL_NAME"
echo ""
echo "To enable at boot:"
echo "  systemctl enable wg-quick@$TUNNEL_NAME"
echo "=============================="

# Ask if the user wants to create clients now
echo ""
echo "Do you want to create clients now? (y/n)"
read CREATE_CLIENTS

if [[ "$CREATE_CLIENTS" == "y" ]]; then
    ./add_peer.sh
fi
