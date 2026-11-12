#!/usr/bin/env bash
# ovs-defense.sh — Defenses on the Open vSwitch node (run on the OVS console).
# Adds OpenFlow rules equivalent to Cisco Port Security + Dynamic ARP Inspection:
#   A) MAC <-> port binding   -> stops Case 1 (MAC spoofing) & Case 2 (CAM overflow)
#   B) IP  <-> MAC ARP binding -> stops Case 3 (ARP poisoning / MITM)
#
# IMPORTANT: in_port=1/2/3 below are EXAMPLES. The real OpenFlow port numbers
# depend on your wiring order. Read the first column of `ovs-ofctl show br0`
# and substitute them, or the rules won't match and the defense won't work.
set -euo pipefail

BR="${1:-br0}"

echo "[*] Current OpenFlow ports on $BR (verify in_port numbers!):"
ovs-ofctl show "$BR" || true

echo "[*] A) MAC <-> port binding (allow correct MAC per port, drop the rest)"
ovs-ofctl add-flow "$BR" "priority=100,in_port=1,dl_src=aa:bb:cc:00:00:50,actions=normal"
ovs-ofctl add-flow "$BR" "priority=100,in_port=2,dl_src=aa:bb:cc:00:00:10,actions=normal"
ovs-ofctl add-flow "$BR" "priority=100,in_port=3,dl_src=aa:bb:cc:00:00:01,actions=normal"
ovs-ofctl add-flow "$BR" "priority=10,actions=drop"

echo "[*] B) IP <-> MAC binding for ARP (only correct pairs pass)"
ovs-ofctl add-flow "$BR" "priority=200,arp,arp_spa=192.168.10.1,dl_src=aa:bb:cc:00:00:01,actions=normal"
ovs-ofctl add-flow "$BR" "priority=200,arp,arp_spa=192.168.10.10,dl_src=aa:bb:cc:00:00:10,actions=normal"
ovs-ofctl add-flow "$BR" "priority=200,arp,arp_spa=192.168.10.50,dl_src=aa:bb:cc:00:00:50,actions=normal"
# drop MUST be priority 150 (above the MAC rules at 100), else a spoofed ARP
# sent with a valid MAC slips through and the defense fails.
ovs-ofctl add-flow "$BR" "priority=150,arp,actions=drop"

echo "[+] Defense rules installed. Inspect with:"
echo "    ovs-ofctl dump-flows $BR    # rules + packet/drop counters"
echo "    ovs-appctl fdb/show $BR     # MAC (CAM) table"
