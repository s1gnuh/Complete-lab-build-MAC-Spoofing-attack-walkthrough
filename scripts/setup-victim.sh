#!/usr/bin/env bash
# setup-victim.sh — Victim (Ubuntu/Lubuntu)
# Pin MAC + IP and set the default route via the gateway.
# Usage:  sudo ./setup-victim.sh [iface]   (default iface: eth0)
# Find your interface name with:  ip link show
set -euo pipefail

IFACE="${1:-eth0}"
MAC="aa:bb:cc:00:00:10"
IP="192.168.10.10/24"
GW="192.168.10.1"

if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)." >&2; exit 1; fi

echo "[*] Pinning MAC $MAC and IP $IP on $IFACE"
ip link set "$IFACE" down
ip link set "$IFACE" address "$MAC"
ip link set "$IFACE" up
ip addr add "$IP" dev "$IFACE" 2>/dev/null || true
ip route add default via "$GW" 2>/dev/null || true
ip addr show "$IFACE"

echo "[+] Done. Victim ready at 192.168.10.10 (gw $GW)"
