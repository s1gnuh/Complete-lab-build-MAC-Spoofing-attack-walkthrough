# Case 1 — MAC Spoofing (identity impersonation)

**English** · [Tiếng Việt](case1-mac-spoofing.vi.md)

> A lab companion for this repo, pre-written to drop into **Chapter 3 — Implementation & Experiments**
> (section **3.3.1**) of the report. It covers: objective, mechanism, attack characteristics, the
> procedure with Before/Attack/After evidence, a summary table, and the conclusion.
>
> Environment: GNS3 + Kali Linux + Open vSwitch (`br0`), flat `192.168.10.0/24` network, **fully isolated,
> no Internet / real network**. Background theory in [report-writing-guide.md](report-writing-guide.md).

---

## 1. Objective

The **Kali** attacker changes its MAC address to the **victim's (PC1)** MAC. Because the switch
(Open vSwitch) learns and forwards frames based on the **Source MAC** field **without authenticating
it**, it confuses the identities: one MAC appears on two ports, and traffic meant for the victim can
be redirected to Kali.

This is the most basic Layer-2 attack, exploiting exactly one fact: *"Ethernet/switches trust the
Source MAC field without verifying it."*

## 2. Attack characteristics (6 criteria)

| Criterion | Detail |
|---|---|
| **(a) Goal** | Impersonate another host to **bypass MAC filtering** (MAC allowlist), evade audit/tracing, or seize an authorized identity. |
| **(b) Mechanism** | Change the NIC's Source MAC to the victim's using `macchanger -m` / `ip link set ... address`. |
| **(c) Precondition** | Same **Layer-2** segment; the legitimate MAC to impersonate is known in advance. |
| **(d) Impact (CIA)** | Mainly **Confidentiality / Authorization** (unauthorized access, control bypass). If the victim is still online → **MAC flapping**, affecting **Availability** (unstable network). |
| **(e) Indicators** | One MAC on **two ports**; the MAC "jumps" between ports; U/L bit = Local (sign of a manually set MAC). |
| **(f) Tools** | `macchanger`, `ip link set ... address`. |

## 3. Preparation — return to a clean state

On **Kali**, restore the real MAC before starting so the baseline is accurate:

```bash
sudo ip link set eth0 down
sudo macchanger -p eth0
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
```

> **Interface name note:** the commands use `eth0`; modern Ubuntu/Kali may name it `ens33` / `enp0s3`.
> Run `ip link show` first to get the real name and substitute it into the commands.

---

## 4. Part A — BEFORE state (no attack yet)

**A1. Kali's real MAC** — Kali terminal:

```bash
macchanger -s eth0
```
→ **Shot 1:** `Current MAC = aa:bb:cc:00:00:50` (the MAC pinned for the attacker).

**A2. Generate traffic so the switch learns the correct MACs** — Kali terminal:

```bash
ping -c 2 192.168.10.10
ping -c 2 192.168.10.1
```

**A3. Switch MAC table (FDB) — clean state** — the **OpenvSwitch** node console:

```bash
ovs-appctl fdb/show br0
```
→ **Shot 2:** each MAC on its own port (Kali = port 1, PC1 = port 2, PC2 = port 3). This is the **baseline**.

## 5. Part B — Run the attack

**B1. Open Wireshark** (second Kali terminal) to record evidence:

```bash
sudo wireshark &
```
Select interface `eth0` → **Start** → set the filter `arp || icmp`.

**B2. Spoof the victim's MAC** — Kali terminal:

```bash
sudo ip link set eth0 down
sudo macchanger -m 00:50:79:66:68:00 eth0   # the victim's MAC (PC1)
sudo ip link set eth0 up
macchanger -s eth0
```
→ **Shot 3:** `Current MAC = 00:50:79:66:68:00 (PRIVATE)` — Kali now carries the victim's MAC.

> `00:50:79:66:68:00` is the victim's actual MAC observed in the GNS3 lab. If your model pins the
> victim to, say, `aa:bb:cc:00:00:10`, use that value instead. Read the real MAC with `ip link show`
> on the victim.

**B3. Generate traffic from Kali (now carrying the victim's identity):**

```bash
ping -c 3 192.168.10.1
```

## 6. Part C — AFTER evidence

**C1. Switch MAC table after the attack** — the **OpenvSwitch** node console:

```bash
ovs-appctl fdb/show br0
```
→ **Shot 4:** MAC `00:50:79:66:68:00` is now on **port 1** (Kali's port) instead of port 2 — **the
switch has been fooled**, the victim's identity is bound to the attacker's port.

**C2. (optional) Wireshark** → **Shot 5:** frames to/from the victim's MAC captured on Kali's NIC,
confirming Kali receives traffic under the victim's name.

## 7. Part D — Restore (clean up after capturing)

```bash
sudo ip link set eth0 down
sudo macchanger -p eth0
sudo ip link set eth0 up
sudo ip addr add 192.168.10.50/24 dev eth0
ip addr show eth0
```

---

## 8. Evidence summary table (for the report)

| Stage | Command | Evidence | Figure |
|---|---|---|---|
| **Before** | `macchanger -s eth0` | Kali MAC = `aa:bb:cc:00:00:50` | Shot 1 |
| **Before** | `ovs-appctl fdb/show br0` | victim MAC on **port 2** | Shot 2 |
| **Attack** | `macchanger -m 00:50:79:66:68:00` | Kali MAC changed to victim's MAC | Shot 3 |
| **After** | `ovs-appctl fdb/show br0` | victim MAC **jumps to port 1 / Kali** | Shot 4 |
| **After** | Wireshark (`arp \|\| icmp`) | Kali captures traffic as the victim *(optional)* | Shot 5 |

## 9. Case 1 conclusion

The attack **succeeds**: by default the switch has **no MAC ↔ port binding**, so it trusts every
Source MAC a host claims. As a result Kali impersonates the victim and makes the FDB record the wrong
port for the victim (MAC flapping from port 2 to port 1).

The root cause is the **lack of Source-MAC authentication at Layer 2** — not a misconfiguration. So the
Defense section will **bind MAC ↔ port** on Open vSwitch (the equivalent of Cisco **Port Security**) to
block exactly this scenario; details and the re-run results (attack fails, `drop` counter increments)
are presented in section **3.4**.

---

<sub>MAC Spoofing lab · Case 1 · for use in an isolated virtual environment for educational purposes.</sub>
