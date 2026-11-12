#!/usr/bin/env bash
# setup-kali.sh — Attacker (Kali Linux)
# Pin a fixed MAC + static IP and install the L2 attack tools.
# Usage:  sudo ./setup-kali.sh [iface]   (default iface: eth0)
# Find your interface name with:  ip link show
set -euo pipefail

IFACE="${1:-eth0}"
MAC="aa:bb:cc:00:00:50"
IP="192.168.10.50/24"

if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)." >&2; exit 1; fi

echo "[*] Pinning MAC $MAC and IP $IP on $IFACE"
ip link set "$IFACE" down
ip link set "$IFACE" address "$MAC"
ip link set "$IFACE" up
ip addr add "$IP" dev "$IFACE" 2>/dev/null || true
ip addr show "$IFACE"

echo "[*] Installing attack tools (Kali usually ships with them)"
apt update
apt install -y macchanger dsniff ettercap-text-only bettercap

echo "[+] Done. Attacker ready at 192.168.10.50"
