#!/bin/bash
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

# PRIMERO: Extraer la clave pública del peer ANTES de eliminar el archivo
echo "Reading peer configuration..."
PEER_PUBKEY=$(grep "PublicKey" $PEER_FILE | cut -d'=' -f2 | tr -d ' ')

if [[ -z "$PEER_PUBKEY" ]]; then
    echo "Warning: Could not find PublicKey in peer configuration file."
fi

echo "Peer public key: $PEER_PUBKEY"

# Mostrar información del peer que se va a eliminar
PEER_IP=$(grep "Address" $PEER_FILE | cut -d'=' -f2 | tr -d ' ')
echo ""
echo "Peer information to remove:"
echo "  Name: $PEER_NAME"
echo "  Public Key: $PEER_PUBKEY"
echo "  IP Address: $PEER_IP"
echo ""

# Confirmar la eliminación
echo "Are you sure you want to remove this peer? (y/n)"
read CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Peer removal cancelled."
    exit 0
fi

# SEGUNDO: Remover la sección del peer del archivo de configuración del túnel
if [[ -n "$PEER_PUBKEY" ]]; then
    echo "Removing peer from tunnel configuration..."
    
    # Crear archivo temporal sin la sección del peer
    awk -v key="$PEER_PUBKEY" -v name="$PEER_NAME" '
    BEGIN { 
        skip_section = 0
        in_peer_section = 0
    }
    
    # Si encontramos un comentario con el nombre del peer, marcar para saltar
    $0 ~ "^# Peer: " name "$" {
        skip_section = 1
        next
    }
    
    # Si estamos saltando y encontramos [Peer], empezar a saltar la sección
    skip_section && /^\[Peer\]/ {
        in_peer_section = 1
        next
    }
    
    # Si estamos en la sección del peer y encontramos la clave pública, confirmar que es el correcto
    in_peer_section && $0 ~ key {
        next
    }
    
    # Si estamos saltando y encontramos otra sección [Peer] o [Interface], parar de saltar
    in_peer_section && (/^\[Peer\]/ || /^\[Interface\]/) {
        skip_section = 0
        in_peer_section = 0
        print
        next
    }
    
    # Si estamos saltando la sección, no imprimir
    skip_section || in_peer_section {
        next
    }
    
    # Imprimir todo lo demás
    {
        print
    }
    ' $WG_CONF > "${WG_CONF}.tmp"
    
    # Verificar que el archivo temporal se creó correctamente
    if [[ -f "${WG_CONF}.tmp" ]]; then
        mv "${WG_CONF}.tmp" $WG_CONF
        echo "Peer $PEER_NAME removed from tunnel configuration $WG_CONF"
    else
        echo "Error: Could not create temporary file. Peer not removed from tunnel configuration."
        exit 1
    fi
else
    echo "Warning: Could not find peer's public key. Skipping tunnel configuration update."
fi

# TERCERO: Eliminar el archivo de configuración del peer
rm -f $PEER_FILE
echo "Peer configuration file $PEER_FILE removed."

echo ""
echo "Peer $PEER_NAME has been successfully removed!"
echo ""
echo "Remember to restart the tunnel if it's currently active:"
echo "  wg-quick down $TUNNEL_NAME"
echo "  wg-quick up $TUNNEL_NAME"
