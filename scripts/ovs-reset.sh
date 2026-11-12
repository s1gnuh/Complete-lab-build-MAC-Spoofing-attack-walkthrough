#!/usr/bin/env bash
# ovs-reset.sh — Remove all OpenFlow rules (back to "no defense") on the OVS node,
# and print the inspection commands you use to gather lab metrics.
set -euo pipefail

BR="${1:-br0}"

echo "[*] Removing all flows on $BR (no-defense baseline)"
ovs-ofctl del-flows "$BR"

echo "[+] Done. Inspection commands:"
echo "    ovs-appctl fdb/show $BR     # view the MAC (CAM) table"
echo "    ovs-ofctl dump-flows $BR    # view rules + packet/drop counters"
echo
echo "[i] Compare method: run each attack Case twice —"
echo "    1) after this reset (no defense), then"
echo "    2) after ./ovs-defense.sh (defense on)."
