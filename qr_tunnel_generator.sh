#!/bin/bash
set -e

# Usamos ruta relativa para coincidir con add_peer.sh
PEERS_DIR="./peers"

clear
echo "=============================="
echo "GLMBX QR GENERATOR"
echo "=============================="

# 1. Comprobar dependencia
if ! command -v qrencode >/dev/null 2>&1; then
    echo "❌ Error: 'qrencode' is not installed."
    echo "Please install it: apt install qrencode / apk add libqrencode"
    exit 1
fi

# 2. Comprobar directorio
if [ ! -d "$PEERS_DIR" ]; then
    echo "❌ No peers directory found at $PEERS_DIR"
    echo "Have you created any peers yet?"
    exit 1
fi

# 3. Buscar archivos .conf (recursivo)
mapfile -t FILES < <(find "$PEERS_DIR" -type f -name "*.conf" | sort)

if [ ${#FILES[@]} -eq 0 ]; then
    echo "❌ No .conf files found in $PEERS_DIR"
    exit 1
fi

echo "Available Client Configs:"
for i in "${!FILES[@]}"; do
    # Limpiamos la ruta para mostrar solo "tunel/usuario.conf" visualmente
    PRETTY_NAME=$(echo "${FILES[$i]}" | sed "s|$PEERS_DIR/||")
    echo "  [$i] $PRETTY_NAME"
done

echo ""
# Preguntar selección
read -p "Select the number to generate QR: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -ge "${#FILES[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

SELECTED="${FILES[$choice]}"
clear
echo "Generando QR para: $(basename "$SELECTED" .conf)"
echo ""

qrencode -t ansiutf8 < "$SELECTED"
echo ""
