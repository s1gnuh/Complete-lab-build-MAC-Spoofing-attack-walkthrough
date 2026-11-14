# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An educational cybersecurity lab: a bilingual (English/Vietnamese) walkthrough for building an
isolated GNS3 + Kali + Open vSwitch network and reproducing three Layer-2 attacks (MAC spoofing,
CAM overflow, ARP/MITM) with matching Open vSwitch defenses. There is **no application to build,
run, or test** — the deliverables are an interactive HTML guide, bash helper scripts, and Markdown
docs. "Running" the lab happens inside GNS3 VMs, not on this machine.

Scope is strictly defensive/educational: content assumes an isolated virtual network with no
Internet or production connectivity. Keep that framing in any content you add.

## The shared addressing contract (most important invariant)

The pinned MAC/IP/port scheme is a single contract duplicated across many files. Changing any
address means updating it **everywhere** or the defenses silently stop matching:

| Host    | IP              | MAC                 | OVS port |
|---------|-----------------|---------------------|----------|
| Kali    | `192.168.10.50` | `aa:bb:cc:00:00:50` | port1    |
| Victim  | `192.168.10.10` | `aa:bb:cc:00:00:10` | port2    |
| Gateway | `192.168.10.1`  | `aa:bb:cc:00:00:01` | port3    |

These values appear in `scripts/setup-*.sh` (where they are pinned onto the VMs),
`scripts/ovs-defense.sh` (where OpenFlow rules match on them), `index.html`, `README.md`, and
`README.vi.md`. A change in one place without the others is the classic bug here.

## OpenFlow rule-priority subtlety

In `scripts/ovs-defense.sh` the priorities are load-bearing, not cosmetic:
- MAC↔port rules at `priority=100`, catch-all drop at `priority=10`.
- ARP IP↔MAC rules at `priority=200`, but the **ARP drop must be `priority=150`** — above the
  MAC rules (100). If it were below, a spoofed ARP sent with a valid source MAC would match a
  `priority=100` `actions=normal` rule and slip through, defeating Case 3. Preserve this ordering.

Also: `in_port=1/2/3` in that script are examples; real OpenFlow port numbers come from
`ovs-ofctl show br0` and depend on wiring order. Don't "correct" them to anything authoritative.

## Bilingual parity (must stay in sync)

Every piece of user-facing content exists in both English and Vietnamese. When editing one side,
mirror the change on the other:
- `README.md` ↔ `README.vi.md`
- `docs/report-writing-guide.md` ↔ `docs/huong-dan-viet-bao-cao.md`
- `index.html` holds **both** languages inline and toggles them with `data-lang="en"` /
  `data-lang="vi"` attributes (~276 elements) plus a JS toggle. Add new content as paired
  `data-lang` elements, not a single-language block.

## index.html

A single self-contained artifact: inline `<style>` and `<script>`, the only external resource is
Google Fonts. CSS is token-driven via `:root` custom properties with three theme definitions that
must be kept parallel — light (`:root`), dark via `@media (prefers-color-scheme:dark)` guarded by
`:root:not([data-theme="light"])`, and explicit `:root[data-theme="dark"]`. Edit colors as tokens,
not hardcoded values. Keep it dependency-free; do not add a bundler or external scripts.

## Scripts

Bash (`#!/usr/bin/env bash`, `set -euo pipefail`), run **inside the lab VMs**, not here (this is a
Windows host). All `setup-*.sh` take an optional interface arg defaulting to `eth0` — modern Ubuntu
uses `ens33`/`enp0s3`, so the iface is intentionally parameterized. `ovs-*.sh` run on the Open
vSwitch node console and take an optional bridge name defaulting to `br0`.
