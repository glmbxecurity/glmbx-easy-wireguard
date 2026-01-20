#!/bin/bash
set -e
WG_DIR="/etc/wireguard"

clear
echo "=============================="
echo "GLMBX WIREGUARD PEER-REMOVER"
echo "=============================="

TUNNELS=($(ls "$WG_DIR" | grep '\.conf$' | sed 's/\.conf//'))
if [ ${#TUNNELS[@]} -eq 0 ]; then echo "No tunnels found"; exit 1; fi

echo "Available tunnels:"
for i in "${!TUNNELS[@]}"; do echo "  $((i+1))) ${TUNNELS[$i]}"; done

while true; do
    read -p "Select tunnel: " TUNNEL_INDEX
    if [[ "$TUNNEL_INDEX" -ge 1 ]] 2>/dev/null && [[ "$TUNNEL_INDEX" -le "${#TUNNELS[@]}" ]]; then
        TUNNEL_NAME="${TUNNELS[$((TUNNEL_INDEX-1))]}"
        break
    fi
done

WG_CONF="$WG_DIR/${TUNNEL_NAME}.conf"
PEERS_DIR="./peers/${TUNNEL_NAME}"
[ ! -d "$PEERS_DIR" ] && { echo "No peers found."; exit 0; }

PEERS=($(ls "$PEERS_DIR" | sed 's/\.conf//'))
if [ ${#PEERS[@]} -eq 0 ]; then echo "No peers found."; exit 0; fi

echo "Available peers:"
for i in "${!PEERS[@]}"; do echo "  $((i+1))) ${PEERS[$i]}"; done

while true; do
    read -p "Select peer to remove: " PEER_INDEX
    if [[ "$PEER_INDEX" -ge 1 ]] 2>/dev/null && [[ "$PEER_INDEX" -le "${#PEERS[@]}" ]]; then
        PEER_NAME="${PEERS[$((PEER_INDEX-1))]}"
        break
    fi
done

PEER_FILE="$PEERS_DIR/${PEER_NAME}.conf"
if [[ ! -f "$PEER_FILE" ]]; then echo "Peer file missing."; exit 1; fi

echo "Removing $PEER_NAME..."
read -p "Are you sure? (y/n) " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then echo "Cancelled."; exit 0; fi

# Borrar bloque del archivo de configuración (Incluye Keepalive y PSK)
awk -v name="$PEER_NAME" '
    BEGIN { skip=0 }
    /^# Peer: / {
        if ($0 == "# Peer: " name) { skip=1; next }
        else { skip=0 }
    }
    { if (skip==0) print }
' "$WG_CONF" > "${WG_CONF}.tmp" && mv "${WG_CONF}.tmp" "$WG_CONF"

rm -f "$PEER_FILE"
echo "✅ Peer $PEER_NAME removed."

# --- HOT RELOAD (Sin reiniciar interfaz) ---
echo "Sincronizando configuración..."
if ip link show "$TUNNEL_NAME" > /dev/null 2>&1; then
    wg syncconf "$TUNNEL_NAME" <(wg-quick strip "$TUNNEL_NAME")
    echo "✅ Cambios aplicados en caliente. Sin cortes."
else
    wg-quick up "$TUNNEL_NAME"
    echo "✅ Túnel iniciado."
fi
