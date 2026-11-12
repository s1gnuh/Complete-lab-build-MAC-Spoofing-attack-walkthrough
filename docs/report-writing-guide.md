# Report Writing Guide — MAC Spoofing Attack

> Companion document to the lab in this repo. Goal: help you write an essay / report that covers the
> **detailed characteristics** of MAC spoofing attacks, and ties the theory to the experimental data
> you collect from `index.html` + `scripts/`.
>
> How to use it: read Parts I–III for the characteristics to present, use Part IV as a chapter outline,
> Part V to turn lab data into tables/figures, Part VI to avoid common mistakes.
>
> Vietnamese version: [huong-dan-viet-bao-cao.md](huong-dan-viet-bao-cao.md)

---

## Part I — Foundations: the MAC address and why it can be spoofed

### 1.1 What a MAC address is
- MAC (Media Access Control) address: a **48-bit** (6-byte) identifier bound to the network card (NIC),
  operating at **Layer 2 (Data Link)** of the OSI model. Example: `aa:bb:cc:00:00:10`.
- Structure: the first 24 bits are the **OUI** (Organizationally Unique Identifier — vendor ID),
  the last 24 bits are the NIC serial. Bit 2 of the first byte is the **U/L** (Universal/Local) bit:
  when a MAC is *set manually* the Local bit is usually set → this is itself a tell-tale sign of a changed MAC.
- The MAC appears in the **Ethernet frame** in two fields: `Destination MAC` and `Source MAC` (6 bytes each),
  before the EtherType field and the payload.

### 1.2 How a switch learns MACs (the mechanism being exploited)
- A switch maintains a **CAM / MAC address table** (on Open vSwitch it is called the **FDB** —
  Forwarding Database).
- When a frame arrives, the switch records the pair `(Source MAC, ingress port)` → it *learns* where a host is.
- To forward a frame: if the `Destination MAC` is known → send out exactly one port (unicast);
  if it is **unknown** (unknown unicast) → **flood** it out every port.
- The table has a bounded size and each entry has an **aging time** (e.g. 300 seconds).

### 1.3 The root vulnerability — the single most important characteristic to state
Ethernet/switches **do not authenticate the Source MAC field**. The switch blindly trusts whatever source
MAC a frame claims. Therefore any machine can:
1. **Claim a MAC that isn't its own** (identity spoofing), and
2. **Inject countless fake MACs** to break the learning mechanism (table overflow).

Every attack in the report stems from one sentence: *"Layer 2 trusts the source MAC without verifying it."*

---

## Part II — Taxonomy and detailed characteristics of MAC spoofing attacks

Present each attack along 6 fixed characteristics (keeps the report consistent and easy to grade):
**(a) Goal · (b) Mechanism · (c) Prerequisites · (d) Impact (CIA) · (e) Indicators · (f) Tools**.

### 2.1 Pure MAC spoofing — identity impersonation (Lab Case 1)
- **(a) Goal:** impersonate another host to **bypass MAC filtering** (a MAC allowlist),
  evade auditing/tracking, or take over an already-authorized identity.
- **(b) Mechanism:** change the NIC's Source MAC to the victim's (`macchanger -m`).
- **(c) Prerequisites:** same **L2 segment**; knowledge of the legitimate MAC to impersonate.
- **(d) Impact:** mainly **Confidentiality/Authorization** (unauthorized access, control bypass).
  If the victim is still online → causes **MAC flapping**, affecting **Availability** (instability).
- **(e) Indicators:** one MAC appearing on **two ports**; a MAC bouncing between ports; U/L bit = Local.
- **(f) Tools:** `macchanger`, `ip link set ... address`.

### 2.2 MAC Flooding / CAM Table Overflow (Lab Case 2)
- **(a) Goal:** force the switch into **fail-open** mode (acting like a hub) to **sniff** other hosts' traffic.
- **(b) Mechanism:** inject thousands of frames with random Source MACs (`macof`) → the CAM table fills →
  the switch can no longer learn/keep legitimate entries → frames to "unknown" destinations get
  **flooded** out every port.
- **(c) Prerequisites:** same L2; a switch with a small CAM table and fail-open behavior.
- **(d) Impact:** **Confidentiality** (sniffing) and **Availability** (switch overload).
- **(e) Indicators:** the CAM table balloons abnormally; a large number of unknown MACs in a short window.
- **(f) Tools:** `macof` (part of dsniff).
- **⚠️ Limitation characteristic — must be stated:** **Open vSwitch** has a large FDB and does **not**
  fail open the way a hardware Cisco switch does, so on this lab Case 2 usually **cannot sniff**. This is
  not your mistake but an **architectural characteristic** — present it as an *experimental finding* and
  as the reason to compare against Cisco (Packet Tracer).

### 2.3 ARP Spoofing + MAC Spoofing → MITM (Lab Case 3)
- **(a) Goal:** sit in the middle (Man-in-the-Middle) between victim ↔ gateway to **read/modify** all traffic.
- **(b) Mechanism:** send **forged ARP replies** mapping `gateway IP → attacker MAC` in the victim's ARP
  cache (and vice versa if full-duplex). Every packet the victim sends "to the gateway" actually reaches the
  attacker; the attacker enables `ip_forward` to relay it so the victim **keeps connectivity** → stealthy attack.
- **(c) Prerequisites:** same L2; no Dynamic ARP Inspection.
- **(d) Impact:** all of **C-I-A**: eavesdropping (C), packet tampering/forgery (I), possible disconnection (A).
- **(e) Indicators:** the victim's `ip neigh` shows the gateway MAC replaced by the attacker's;
  one MAC bound to **multiple IPs**; unsolicited (gratuitous) ARP replies.
- **(f) Tools:** `bettercap` (or `ettercap`, `arpspoof`).

> **Relationship to explain in the report:** ARP spoofing is a *consequence / advanced form* of Layer-2
> spoofing — it abuses the fact that ARP (the IP↔MAC mapping protocol) is **also unauthenticated**. So MAC
> and ARP attacks are tightly coupled: MAC controls (Port Security) stop 2.1–2.2, ARP controls (DAI) stop 2.3.

---

## Part III — Defense characteristics (for the solution chapter)

Present each measure as: **principle · which case it stops · strengths · limitations**.

| Measure | Principle | Stops | Limitations |
|---|---|---|---|
| **Port Security** (Cisco) / **MAC↔port binding** (OVS rule A) | Each port allows only one preset MAC; violation → err-disabled/drop | Case 1, 2 | Hard to manage on large/mobile networks; doesn't stop forged ARP if the MAC is still valid |
| **DHCP Snooping** | Builds a trusted IP↔MAC↔port table from DHCP transactions | (basis for DAI) | Requires DHCP hosts; many Packet Tracer builds don't support it |
| **Dynamic ARP Inspection (DAI)** / **ARP IP↔MAC binding** (OVS rule B) | Drops ARP with wrong IP–MAC pairs on untrusted ports | Case 3 | Needs correct bindings; manual rules easily miss `arp_sha`/`in_port` (see below) |
| **802.1X** | Authenticates the device before it is allowed onto the network | 1, 2, 3 (at the root) | Needs RADIUS infrastructure; out of lab scope |
| **Encryption (TLS/VPN)** | Assumes an untrusted network; protects *content* even under MITM | Reduces impact of 3 | Doesn't prevent the attack, only limits damage → "defense in depth" |

### 3.1 Distinguish the two defense types (a point worth stressing)
- **Preventive:** static OVS rules, Port Security — block **instantly**, there is no "detection time".
- **Detective/reactive:** arpwatch, IDS alerting on duplicate/flapping MACs — has latency.

This lab is in the **preventive** group, so when reporting the "block time" criterion, interpret it as
*blocked from the very first packet* — don't invent a "detection time".

### 3.2 Limitation of the sample OVS rules (material for "future improvements")
The sample ARP rules in the lab only check `dl_src` + `arp_spa`; they do **not** check `in_port` or `arp_sha`
(the sender MAC inside the ARP payload). They stop default bettercap, but a sophisticated attacker (setting
`dl_src` = gateway MAC and `arp_sha` = their own MAC) can still slip through. A "real" DAI binds all of
**IP ↔ Ethernet-src ↔ arp_sha ↔ correct port** at once. Noting this shows deep understanding rather than
just following the walkthrough.

---

## Part IV — Suggested chapter outline for the report

This lab corresponds to **Chapter 3 (Implementation & Experiments)**. A full suggested outline:

- **Chapter 1 — Introduction**
  - 1.1 Motivation · 1.2 Objectives & scope · 1.3 Methodology (isolated virtual lab) · 1.4 Structure
- **Chapter 2 — Theoretical background** (based on Parts I–II of this guide)
  - 2.1 OSI model & Layer 2, the Ethernet frame, the MAC address
  - 2.2 How a switch learns MACs (CAM/FDB)
  - 2.3 The root vulnerability: no authentication of the Source MAC
  - 2.4 Attack taxonomy: MAC spoofing, CAM overflow, ARP+MAC MITM
  - 2.5 Overview of defense measures (Part III)
- **Chapter 3 — Implementation & Experiments** (this lab)
  - 3.1 Network model design (topology, addressing table — insert the diagram + GNS3 screenshots)
  - 3.2 Environment build (GNS3 + Kali + OVS; per-host config; baseline ping results)
  - 3.3 Executing the attacks (Case 1–3, with Wireshark / `ip neigh` / `fdb/show` screenshots)
  - 3.4 Deploying defenses on OVS and re-running to verify
  - 3.5 Comparison to the enterprise standard via Cisco Packet Tracer (Port Security, DAI)
  - 3.6 Measurement results (before/after comparison table — see Part V)
- **Chapter 4 — Evaluation & Discussion**
  - 4.1 Result analysis · 4.2 Limitations (OVS vs Cisco for Case 2; the ARP-rule gap) · 4.3 Future improvements
- **Chapter 5 — Conclusion**

> If the assignment is a short essay rather than a full project, collapse into: *Introduction → Theory →
> Experiment (demo) → Defense → Conclusion*, keeping the spirit of the sections above.

---

## Part V — Turning lab data into report results

### 5.1 Main results table (fill from the worksheet in `index.html`)

| Case | No defense | Defense on (OVS) | Evidence |
|---|---|---|---|
| 1 — MAC Spoofing | Succeeds / bypasses MAC filter | Dropped at the switch | `dump-flows` drop counter; `fdb/show` screenshot |
| 2 — CAM Overflow | *(OVS: does not fail open — concept demo)* | N/A | `fdb/show` entry count before/after |
| 3 — ARP MITM | MITM succeeds, traffic captured | Forged ARP rejected | victim `ip neigh` before/after; bettercap log |

### 5.2 The five measurement criteria (already in the lab) and how to get the numbers
1. **Attack succeeded?** — did Wireshark capture the victim's traffic (yes/no + screenshot).
2. **Volume/ratio of malicious frames blocked** — `ovs-ofctl dump-flows br0`, read `n_packets` of the drop rule.
3. **Block time** — rules are pre-installed ⇒ blocked from the first packet (interpret as *preventive*, see 3.1).
4. **Impact on valid traffic (false positives)** — does victim↔gateway ping break when the defense is on.
5. **Fake MACs in CAM** — `ovs-appctl fdb/show br0`, count entries before/after the attack.

### 5.3 Required screenshots (gather these for the report)
- GNS3 topology + the three baseline ping results (sections 3.1–3.2).
- Each Case: the **before** state (no-defense, attack succeeds) and **after** (defense-on, blocked).
- `dump-flows` with the drop counter increasing; `fdb/show` before/after; victim `ip neigh` before/after (Case 3).
- Packet Tracer: the port going **err-disabled** after a MAC spoof (section 3.5).

---

## Part VI — Checklist & common mistakes (so you don't lose marks)

**Submission checklist**
- [ ] State the **root vulnerability** clearly (no authentication of the Source MAC) — don't just list tools.
- [ ] Present each attack with all 6 characteristics (a–f in Part II).
- [ ] Back every result with a **screenshot**, clearly labeled "before/after", "no-defense/defense-on".
- [ ] Honestly present the Case 2 limitation on OVS as a **finding**, not something hidden.
- [ ] Include the **Cisco comparison** (3.5) to show the solution matches the enterprise standard.
- [ ] In limitations, mention the ARP-rule gap (missing `arp_sha`/`in_port`) — bonus points for depth.
- [ ] Cite your sources (see below).

**Common mistakes**
- Confusing Layer 2 (MAC) with Layer 3 (IP); calling ARP spoofing an "IP attack".
- Assuming `macof` will definitely work on OVS → wrong expectation, wasted time.
- Forgetting NetworkManager overwrites the MAC/IP → thinking the command failed (stop NetworkManager
  before pinning).
- Forgetting to replace `in_port=1/2/3` with the real port numbers from `ovs-ofctl show br0` → the
  defense "doesn't work".
- Calling the static defense "detective" instead of "preventive".
- Only pasting commands, with no **mechanism explanation** and no **data analysis**.

**Suggested sources to cite**
- IEEE 802.1D / 802.1Q (bridging, VLANs); IEEE 802.1X (port-based authentication).
- RFC 826 (ARP).
- Cisco documentation: Port Security, DHCP Snooping, Dynamic ARP Inspection.
- Open vSwitch documentation: `ovs-ofctl`, OpenFlow fields (`arp_spa`, `arp_sha`, `dl_src`).
- Man pages: `macchanger`, `macof` (dsniff), `bettercap`.

---

<sub>MAC Spoofing lab companion · for educational use in an isolated virtual environment.</sub>
