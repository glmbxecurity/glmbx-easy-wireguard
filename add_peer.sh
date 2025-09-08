#!/bin/sh
set -e
WG_DIR="/etc/wireguard"
CONFIG_FILE="config.txt"

clear
echo "=============================="
echo "GLMBX WIREGUARD PEER-CREATOR"
echo "=============================="

# Verificar que existe el archivo de configuración
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

# Cargar configuración desde config.txt
source "$CONFIG_FILE"

# List available tunnels
echo "Available tunnels:"
ls "$WG_DIR" | grep '\.conf$' | sed 's/\.conf//'
echo "Enter the name of the tunnel to which you want to add peers:"
read TUNNEL_NAME

WG_CONF="$WG_DIR/${TUNNEL_NAME}.conf"
if [ ! -f "$WG_CONF" ]; then
    echo "Tunnel $TUNNEL_NAME not found in $WG_DIR"
    exit 1
fi

# Server pubkey
SERVER_PUBKEY_FILE="$WG_DIR/${TUNNEL_NAME}-pubkey"
if [ ! -f "$SERVER_PUBKEY_FILE" ]; then
    echo "Server public key file $SERVER_PUBKEY_FILE not found!"
    exit 1
fi
SERVER_PUBKEY=$(cat "$SERVER_PUBKEY_FILE")

# Usar los valores del config.txt en lugar de buscarlos en el archivo de configuración
# Ya están cargados: ENDPOINT, PORT, TUNNEL_NET, DNS

# Verificar que los valores necesarios existen
if [ -z "$ENDPOINT" ] || [ -z "$PORT" ] || [ -z "$TUNNEL_NET" ]; then
    echo "ERROR: Endpoint, Port or TUNNEL_NET is empty in $CONFIG_FILE"
    echo "ENDPOINT: $ENDPOINT"
    echo "PORT: $PORT" 
    echo "TUNNEL_NET: $TUNNEL_NET"
    exit 1
fi

# Peers folder
PEERS_DIR="./peers/${TUNNEL_NAME}"
mkdir -p "$PEERS_DIR"

while true; do
    echo ""
    echo "Peer name:"
    read PEER_NAME
    
    echo "Do you want to route all traffic through the tunnel? (y/n)"
    read ROUTE_ALL
    if [ "$ROUTE_ALL" = "y" ]; then
        ALLOWED_IPS="0.0.0.0/0"
    else
        echo "Enter the networks to route (e.g., 192.168.1.0/24,10.0.0.0/8):"
        read ALLOWED_IPS
    fi
    
    echo "Do you want to use the default DNS ($DNS)? (y/n)"
    read USE_DEFAULT_DNS
    if [ "$USE_DEFAULT_DNS" = "y" ]; then
        DNS_FINAL=$DNS
    else
        echo "Enter the DNS you want to use:"
        read DNS_FINAL
    fi
    
    # Peer keys
    PEER_PRIVKEY=$(wg genkey)
    PEER_PUBKEY=$(echo "$PEER_PRIVKEY" | wg pubkey)
    
    # Calcular siguiente IP libre - CORREGIDO
    TUNNEL_BASE=$(echo "$TUNNEL_NET" | cut -d'/' -f1 | awk -F. '{print $1 "." $2 "." $3 "."}')
    
    # Obtener IPs usadas de forma más robusta
    USED_IPS=$(grep -E "AllowedIPs.*\." "$WG_CONF" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/32" | cut -d'/' -f1 | awk -F. '{print $4}' | sort -n)
    
    # Encontrar el siguiente octeto libre
    NEXT_OCTET=2
    for ip in $USED_IPS; do
        if [ "$ip" -eq "$NEXT_OCTET" ]; then
            NEXT_OCTET=$((NEXT_OCTET+1))
        else
            break
        fi
    done
    
    PEER_IP="${TUNNEL_BASE}${NEXT_OCTET}"
    
    # Mostrar información del peer que se va a crear
    echo ""
    echo "Creating peer with the following configuration:"
    echo "  Name: $PEER_NAME"
    echo "  IP: $PEER_IP/24"
    echo "  DNS: $DNS_FINAL"
    echo "  Endpoint: $ENDPOINT:$PORT"
    echo "  AllowedIPs: $ALLOWED_IPS"
    echo ""
    
    # Peer config
    PEER_FILE="$PEERS_DIR/${PEER_NAME}.conf"
    cat > "$PEER_FILE" <<EOF
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
    
    # Add peer to server
    cat >> "$WG_CONF" <<EOF
# Peer: $PEER_NAME
[Peer]
PublicKey = $PEER_PUBKEY
AllowedIPs = $PEER_IP/32
EOF
    
    echo "Peer $PEER_NAME added to $WG_CONF"
    
    # Mostrar el código QR si qrencode está disponible
    if command -v qrencode >/dev/null 2>&1; then
        echo ""
        echo "QR Code for $PEER_NAME:"
        qrencode -t ansiutf8 < "$PEER_FILE"
    fi
    
    echo ""
    echo "Do you want to add another peer to $TUNNEL_NAME? (y/n)"
    read ADD_ANOTHER
    [ "$ADD_ANOTHER" = "y" ] || { echo "Finished adding peers."; break; }
done
