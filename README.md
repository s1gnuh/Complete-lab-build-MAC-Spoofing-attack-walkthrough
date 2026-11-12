# Complete lab build & MAC Spoofing attack walkthrough

**English** · [Tiếng Việt](README.vi.md)

A hands-on lab for building an **isolated virtual network** and reproducing classic Layer-2
attacks against it — with matching defenses and a measurement worksheet. Built on
**GNS3 + Kali Linux + Open vSwitch**, with a Cisco **Packet Tracer** supplement for
enterprise-standard comparison.

The full interactive guide is in [`index.html`](index.html) — open it in a browser for the
step-by-step walkthrough with copyable commands, a topology diagram, and a fillable results
worksheet (VI/EN toggle in the top-right).

Writing a report? See the companion guide in [`docs/report-writing-guide.md`](docs/report-writing-guide.md).

---

## ⚠️ Scope & ethics

**For educational use inside your own isolated virtual lab only.** Run every attack solely on
the isolated virtual network (GNS3, **no connection to the Internet or a production/school
network**). Attacking any network or device without authorization is illegal.

---

## Topology & addressing

A flat `192.168.10.0/24` network. Three hosts plug into one Open vSwitch bridge (`br0`).

| Host              | Role               | IP              | MAC (example)       | Port  |
|-------------------|--------------------|-----------------|---------------------|-------|
| Kali Linux        | attacker           | `192.168.10.50` | `aa:bb:cc:00:00:50` | port1 |
| Ubuntu / Lubuntu  | victim             | `192.168.10.10` | `aa:bb:cc:00:00:10` | port2 |
| Ubuntu / Lubuntu  | gateway / server   | `192.168.10.1`  | `aa:bb:cc:00:00:01` | port3 |

> **Note:** the MAC column is the MAC you *pin* on each VM so defense rules are easy to write.
> Record the real MACs with `ip link show`, and replace `eth0` in the scripts with your actual
> interface name (modern Ubuntu often uses `ens33` / `enp0s3`).

---

## Software you need

| Software | Used for |
|---|---|
| GNS3 + GNS3 VM (VMware) | Network simulation platform |
| VMware Workstation / Player | Runs the GNS3 VM and guest VMs |
| Open vSwitch appliance | The L2 switch (free from the GNS3 Marketplace) |
| Kali Linux (VM) | Attacker machine |
| Ubuntu / Lubuntu (VM) | Victim + Gateway (clone twice) |
| Wireshark | Packet capture, proof of results |

**RAM:** the lab runs 4 VMs at once, so you realistically need **16 GB**. On 8 GB, lighten the
load (swap the Ubuntu VMs for GNS3 Docker appliances or VPCS nodes). Enable VT-x/AMD-V in BIOS.

---

## Quick start

1. Build the GNS3 topology and install the **Open vSwitch** appliance (see `index.html` → *VM setup*).
2. Configure each host. The commands are packaged as scripts in [`scripts/`](scripts/):

   ```bash
   # On Kali (attacker)
   sudo ./scripts/setup-kali.sh eth0

   # On the victim
   sudo ./scripts/setup-victim.sh eth0

   # On the gateway
   sudo ./scripts/setup-gateway.sh eth0
   ```

   > Replace `eth0` with your real interface name from `ip link show`.

3. Verify connectivity, then run the attacks **with defenses off**, capturing in Wireshark.
4. Apply defenses on the OVS console and re-run each attack to confirm it fails:

   ```bash
   # On the Open vSwitch node console
   ./scripts/ovs-defense.sh      # add MAC↔port + IP↔MAC ARP binding rules
   ./scripts/ovs-reset.sh        # remove all rules (back to "no defense")
   ```

---

## Three attack scenarios

| # | Attack | Idea | Tool |
|---|--------|------|------|
| 1 | **MAC Spoofing** | Impersonate the victim's MAC to bypass MAC filtering | `macchanger` |
| 2 | **CAM Table Overflow** | Flood the MAC table to force hub-like behavior | `macof` |
| 3 | **ARP + MAC Spoofing (MITM)** | ARP-poison victim↔gateway to intercept traffic | `bettercap` |

> **Case 2 limit:** Open vSwitch has a large MAC table and behaves differently from hardware
> switches, so `macof` may not push OVS into "hub" mode the way real Cisco gear does. If you
> can't capture traffic, present Case 2 as a concept demo and base your main numbers on
> Cases 1 & 3.

---

## Defenses

- **Open vSwitch (OpenFlow)** — bind MAC↔port (stops Case 1 & 2) and IP↔MAC for ARP (stops
  Case 3). See [`scripts/ovs-defense.sh`](scripts/ovs-defense.sh).
- **Cisco Packet Tracer** — the enterprise-standard equivalent: Port Security, DHCP Snooping,
  and Dynamic ARP Inspection. Config and notes in `index.html` → *Packet Tracer*.

---

## Measurement criteria

- Attack succeeded? (does Wireshark capture the victim's traffic)
- Malicious frames blocked (`ovs-ofctl dump-flows br0` drop counters)
- Detection/block time (timestamp from attack start to first drop)
- Impact on valid traffic (does victim↔gateway ping break — false positives)
- Fake MACs in CAM table (`ovs-appctl fdb/show br0` before/after)

---

## Repository layout

```
.
├── index.html                      # Full interactive bilingual lab guide
├── scripts/
│   ├── setup-kali.sh               # Attacker: pin MAC + static IP, install tools
│   ├── setup-victim.sh             # Victim: MAC + IP + default route
│   ├── setup-gateway.sh            # Gateway: MAC + IP + ip_forward
│   ├── ovs-defense.sh              # OpenFlow MAC↔port & ARP IP↔MAC binding rules
│   └── ovs-reset.sh                # Remove all flows + helpful inspection commands
├── docs/
│   ├── report-writing-guide.md     # Report-writing companion (English)
│   └── huong-dan-viet-bao-cao.md   # Report-writing companion (Vietnamese)
├── LICENSE
└── README.md
```

---

<sub>🤖 Generated with [Claude Code](https://claude.com/claude-code)</sub>
