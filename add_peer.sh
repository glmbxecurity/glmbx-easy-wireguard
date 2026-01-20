#!/bin/bash
set -e
WG_DIR="/etc/wireguard"
CONFIG_FILE="config.txt"
# KEEPALIVE: 25s es el estándar para evitar cortes por NAT y asegurar monitoreo
KEEPALIVE=25

clear
echo "=============================="
echo "GLMBX WIREGUARD PEER-CREATOR"
echo "=============================="

# Verificar config.txt
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

source "$CONFIG_FILE"

# Listar túneles
echo "Available tunnels:"
TUNNELS=($(ls "$WG_DIR" | grep '\.conf$' | sed 's/\.conf//'))
if [ ${#TUNNELS[@]} -eq 0 ]; then
    echo "No WireGuard tunnels found in $WG_DIR"
    exit 1
fi

for i in "${!TUNNELS[@]}"; do
    echo "  $((i+1))) ${TUNNELS[$i]}"
done

while true; do
    echo ""
    read -p "Select the tunnel number: " TUNNEL_INDEX
    if [ "$TUNNEL_INDEX" -ge 1 ] 2>/dev/null && [ "$TUNNEL_INDEX" -le "${#TUNNELS[@]}" ]; then
        TUNNEL_NAME="${TUNNELS[$((TUNNEL_INDEX-1))]}"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

WG_CONF="$WG_DIR/${TUNNEL_NAME}.conf"
SERVER_PUBKEY_FILE="$WG_DIR/${TUNNEL_NAME}-pubkey"

# Obtener Server Public Key
if [ -f "$SERVER_PUBKEY_FILE" ]; then
    SERVER_PUBKEY=$(cat "$SERVER_PUBKEY_FILE")
    echo "Using server public key from file."
else
    echo "Extracting server public key from configuration..."
    SERVER_PRIVKEY=$(grep "PrivateKey" "$WG_CONF" | head -n1 | cut -d'=' -f2 | tr -d ' ')
    SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | wg pubkey)
fi

# Directorio de peers
PEERS_DIR="./peers/${TUNNEL_NAME}"
mkdir -p "$PEERS_DIR"

while true; do
    echo ""
    echo "Peer name:"
    read PEER_NAME
    
    echo "Route all traffic? (y/n)"
    read ROUTE_ALL
    if [ "$ROUTE_ALL" = "y" ]; then
        ALLOWED_IPS="0.0.0.0/0"
    else
        echo "Enter allowed IPs (e.g. 192.168.1.0/24):"
        read ALLOWED_IPS
    fi
    
    echo "Use default DNS ($DNS)? (y/n)"
    read USE_DEFAULT_DNS
    [ "$USE_DEFAULT_DNS" = "y" ] && DNS_FINAL=$DNS || { echo "Enter DNS:"; read DNS_FINAL; }
    
    echo "Add PresharedKey? (y/n)"
    read ADD_PSK
    [ "$ADD_PSK" = "y" ] && PRESHARED_KEY=$(wg genpsk) || PRESHARED_KEY=""
    
    # Generar llaves cliente
    PEER_PRIVKEY=$(wg genkey)
    PEER_PUBKEY=$(echo "$PEER_PRIVKEY" | wg pubkey)
    
    # Calcular IP libre
    TUNNEL_BASE=$(echo "$TUNNEL_NET" | cut -d'/' -f1 | awk -F. '{print $1 "." $2 "." $3 "."}')
    USED_IPS=$(grep -E "AllowedIPs.*\." "$WG_CONF" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/32" | cut -d'/' -f1 | awk -F. '{print $4}' | sort -n | uniq)
    
    for i in $(seq 2 254); do
        if ! echo "$USED_IPS" | grep -q "^$i\$"; then
            NEXT_OCTET=$i
            break
        fi
    done
    
    if [ -z "$NEXT_OCTET" ]; then echo "ERROR: No free IPs available"; exit 1; fi
    PEER_IP="${TUNNEL_BASE}${NEXT_OCTET}"
    
    # --- GENERAR ARCHIVO CLIENTE ---
    PEER_FILE="$PEERS_DIR/${PEER_NAME}.conf"
    cat > "$PEER_FILE" <<EOF
[Interface]
PrivateKey = $PEER_PRIVKEY
Address = $PEER_IP/32
DNS = $DNS_FINAL
MTU = 1280

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $ENDPOINT:$PORT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = $KEEPALIVE
EOF
    [ -n "$PRESHARED_KEY" ] && echo "PresharedKey = $PRESHARED_KEY" >> "$PEER_FILE"
    
    # --- ACTUALIZAR SERVIDOR ---
    cat >> "$WG_CONF" <<EOF
# Peer: $PEER_NAME
[Peer]
PublicKey = $PEER_PUBKEY
AllowedIPs = $PEER_IP/32
PersistentKeepalive = $KEEPALIVE
EOF
    [ -n "$PRESHARED_KEY" ] && echo "PresharedKey = $PRESHARED_KEY" >> "$WG_CONF"
    
    echo "✅ Peer $PEER_NAME added ($PEER_IP)"

    # Mostrar QR
    if command -v qrencode >/dev/null 2>&1; then
        echo "QR Code for $PEER_NAME:"
        qrencode -t ansiutf8 < "$PEER_FILE"
    fi

    echo "Add another? (y/n)"
    read ADD_ANOTHER
    [ "$ADD_ANOTHER" = "y" ] || break
done

# --- HOT RELOAD (Sin reiniciar interfaz) ---
echo "Aplicando cambios..."
if ip link show "$TUNNEL_NAME" > /dev/null 2>&1; then
    # Sincronización en caliente
    wg syncconf "$TUNNEL_NAME" <(wg-quick strip "$TUNNEL_NAME")
    echo "✅ Cambios aplicados en caliente. Sin cortes."
else
    # Si estaba apagado, encender
    wg-quick up "$TUNNEL_NAME"
    echo "✅ Túnel iniciado."
fi
