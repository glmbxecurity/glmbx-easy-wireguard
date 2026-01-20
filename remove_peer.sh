#!/bin/bash
clear
set -e

CONFIG_FILE="config.txt"

# Verificar archivo de configuración
if [[ ! -f $CONFIG_FILE ]]; then
    echo "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

# Cargar configuración
source $CONFIG_FILE

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

# Confirmación
echo "Do you confirm the tunnel creation with these settings? (y/n)"
read CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Tunnel creation cancelled."
    exit 0
fi

# Preguntar por NAT y Forwarding (CRUCIAL PARA TENER INTERNET)
echo ""
echo "Do you want to enable IP forwarding and allow access to internet/other networks? (y/n)"
read ENABLE_FORWARDING

MAIN_IFACE=""
if [[ "$ENABLE_FORWARDING" == "y" ]]; then
    echo ""
    echo "Available network interfaces:"
    # Comando compatible con Alpine/Bash para mostrar interfaces
    ip -br link show | grep -v "^lo" | awk '{print "  - " $1}'
    echo ""
    echo "Enter the network interface for internet/network access (e.g., eth0, wlan0):"
    read MAIN_IFACE
    
    if [[ -z "$MAIN_IFACE" ]]; then
        echo "Error: No interface specified. Tunnel creation cancelled."
        exit 1
    fi
fi

WG_CONF="/etc/wireguard/${TUNNEL_NAME}.conf"
PRIV_FILE="/etc/wireguard/${TUNNEL_NAME}-privkey"
PUB_FILE="/etc/wireguard/${TUNNEL_NAME}-pubkey"

# Generar llaves del servidor
SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo $SERVER_PRIVKEY | wg pubkey)

# Guardar llaves (Permisos seguros)
echo "$SERVER_PRIVKEY" > "$PRIV_FILE"
chmod 600 "$PRIV_FILE"
echo "$SERVER_PUBKEY" > "$PUB_FILE"
chmod 644 "$PUB_FILE"

# Crear archivo de configuración wg0.conf
cat > $WG_CONF <<EOF
[Interface]
PrivateKey = $SERVER_PRIVKEY
Address = $SERVER_IP
ListenPort = $PORT
DNS = $DNS
#TUNNEL_NET = $TUNNEL_NET  # for reference only

EOF

# Añadir reglas de Firewall (NAT) si se solicitó
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
    echo "✅ IP forwarding and NAT rules added."
    echo "Output interface configured: $MAIN_IFACE"
    
    # Hacer persistente el forwarding en Alpine/Linux
    echo ""
    echo "Do you want to make IP forwarding permanent in /etc/sysctl.conf? (y/n)"
    read MAKE_PERMANENT
    
    if [[ "$MAKE_PERMANENT" == "y" ]]; then
        if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
            # Aplicar cambio inmediatamente
            sysctl -p > /dev/null 2>&1
            echo "✅ IP forwarding enabled permanently."
        else
            echo "ℹ️  IP forwarding was already enabled."
        fi
    fi
fi

echo ""
echo "=============================="
echo "Tunnel $TUNNEL_NAME created successfully!"
echo "=============================="
echo "Config file: $WG_CONF"
echo "Public Key:  $PUB_FILE"
echo ""
echo "--- HOW TO START ---"
echo "Manual start:  wg-quick up $TUNNEL_NAME"
echo "Autostart (Alpine): rc-update add wg-quick.$TUNNEL_NAME default"
echo "=============================="
echo ""

# Preguntar si quiere iniciarlo AHORA MISMO
echo "Do you want to START the tunnel now? (y/n)"
read START_NOW

if [[ "$START_NOW" == "y" ]]; then
    echo "Starting tunnel..."
    # Intentamos bajarlo primero por si se quedó pillado, sin mostrar errores
    wg-quick down "$TUNNEL_NAME" > /dev/null 2>&1 || true
    # Lo subimos
    if wg-quick up "$TUNNEL_NAME"; then
        echo "✅ Tunnel is UP and Running!"
    else
        echo "❌ Error starting tunnel. Check configuration."
    fi
fi

# Preguntar si quiere crear clientes
echo ""
echo "Do you want to create clients (peers) now? (y/n)"
read CREATE_CLIENTS

if [[ "$CREATE_CLIENTS" == "y" ]]; then
    ./add_peer.sh
fi
