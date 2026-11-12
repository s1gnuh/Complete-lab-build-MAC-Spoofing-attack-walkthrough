#!/usr/bin/env bash
# setup-gateway.sh — Gateway/Server (Ubuntu/Lubuntu)
# Pin MAC + IP and enable IPv4 forwarding to act as the gateway.
# Usage:  sudo ./setup-gateway.sh [iface]   (default iface: eth0)
# Find your interface name with:  ip link show
set -euo pipefail

IFACE="${1:-eth0}"
MAC="aa:bb:cc:00:00:01"
IP="192.168.10.1/24"

if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)." >&2; exit 1; fi

echo "[*] Pinning MAC $MAC and IP $IP on $IFACE"
ip link set "$IFACE" down
ip link set "$IFACE" address "$MAC"
ip link set "$IFACE" up
ip addr add "$IP" dev "$IFACE" 2>/dev/null || true

echo "[*] Enabling IPv4 forwarding"
sysctl -w net.ipv4.ip_forward=1

ip addr show "$IFACE"
echo "[+] Done. Gateway ready at 192.168.10.1 (forwarding on)"
