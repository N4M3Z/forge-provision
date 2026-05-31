---
title: Parallels Desktop setup
description: When Parallels is adopted per ARCH-0016's trigger, the install is via official DMG (ARCH-0014), the VMs are Windows 11 ARM and a macOS guest, and the recommended settings cover resource allocation, network mode, shared folders, and Coherence.
type: adr
category: tooling
tags:
    - parallels
    - virtualization
    - windows
    - macos-guest
    - vm
status: accepted
created: 2026-05-30
updated: 2026-05-30
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0014 Brewfile vs manual DMG criteria.md"
    - "ARCH-0016 Virtualization stack.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://kb.parallels.com/en/124781
    - https://kb.parallels.com/en/128868
---

# Parallels Desktop setup

## Context and Problem Statement

[ARCH-0016][16] decides *when* to install Parallels Desktop: only when a concrete DirectX or Coherence-mode wall surfaces with VMware Fusion or OrbStack. When that trigger fires and Parallels is installed, the next questions are operational: which VMs to create, what resources to allocate, what network mode, what shared folders, how to migrate from a prior machine.

[ARCH-0014][14] decides *how* to install: official DMG, not Homebrew cask, paired with a Brewfile tombstone. This ADR sits inside that install and covers the configuration knobs.

The Apple Silicon Parallels stack ships with sensible defaults for most knobs, but a few defaults are wrong for a multi-VM dev workflow (auto-allocated RAM that competes with the host, default Shared network that loses on UDP, Coherence enabled for every guest including macOS where it makes no sense). This ADR pins the configuration.

## Decision Drivers

- Resources allocated to VMs must not starve the host — the user is on the host all day
- Network mode must support the guest's intended use (Bridged for development services that need direct LAN access, Shared for default isolation, Host-only for offline test environments)
- Shared folders are required for cross-VM workflows but introduce attack surface and must be scoped narrowly
- VM templates should be reproducible — a destroyed VM should rebuild from notes, not a 4-hour install spree
- Migration from the prior Mac's Parallels install should be supported by Parallels' own transfer mechanism, with Time Machine as the fallback

## Considered Options

### VM roster

1. **Windows 11 ARM only.** Sufficient for occasional Windows access. Skip the macOS guest — Apple's Virtualization.framework can host one separately if needed.
2. **Windows 11 ARM + macOS guest** for testing macOS-on-macOS scenarios (clean install verification, dev sandbox isolation, screenshot guides). The macOS guest is technically possible only on Apple Silicon and only with limited concurrent count.
3. **Linux guest as well.** Redundant with OrbStack ([ARCH-0016][16]); skip.

### Resource allocation strategy

A. **Parallels auto-allocate.** Convenient but greedy under memory pressure.
B. **Fixed allocation per VM, host-aware.** Pin CPU and RAM per VM so the host always has enough headroom.

### Network mode

α. **Shared (default).** NAT through the host. Works for most outbound use cases. Loses on inbound connections from the LAN to the VM.
β. **Bridged.** VM gets its own IP on the LAN. Required for any dev service hosted in the VM that another LAN device needs to reach.
γ. **Host-only.** No external network. Offline testing.

## Decision Outcome

Chosen options: **2 + B + per-VM network mode**.

### VM roster

- **Windows 11 ARM** — the workhorse VM. Loaded with the user's standard Windows toolchain (Visual Studio, Office, anything that requires Windows-only software).
- **macOS guest** — used for clean-install verification, dev sandbox isolation, and visual-walkthrough screenshots. macOS guest count is capped at 2 by Apple's Virtualization.framework; the configured guest counts as one of those slots.

No Linux guest. OrbStack handles every Linux workload more efficiently per ARCH-0016.

### Resource allocation

Pin resources per VM, leaving host headroom. The host has the user's daily workflow and should not feel allocation pressure.

| VM | CPU cores | RAM | Disk |
| -- | --------: | --: | ---: |
| Windows 11 ARM | 4 performance cores | 8 GB | 128 GB expanding |
| macOS guest | 4 performance cores | 8 GB | 80 GB expanding |

Host headroom target: at least 16 GB RAM and 4 performance cores reserved when both VMs are running concurrently. On the M5-class machine (Mac17,6) this leaves comfortable margin. Adjust downward if either VM is the sole running guest.

### Network mode (per VM)

- **Windows 11 ARM**: Shared (default NAT). The VM is a Windows-app host, not a service host. NAT is sufficient and keeps the VM out of LAN discovery.
- **macOS guest**: Shared by default. Switch to Bridged ad-hoc when testing a service that needs LAN reachability.

### Shared folders

- **Default**: deny everything except an explicit allow list. Parallels' default of sharing the entire home directory is too broad.
- **Allow list**: `~/Developer/<repo>` for the specific repo being worked on inside the VM. Add per-session as needed; remove when done.
- **Clipboard sharing**: text only. Disable file sharing via clipboard to avoid accidental binary drops.
- **Mouse and keyboard sharing**: enabled.

### Coherence mode

- **Windows 11 ARM**: Coherence enabled. Running Windows apps as if they were native macOS apps is the main reason to choose Parallels over VMware Fusion ([ARCH-0016][16]).
- **macOS guest**: Coherence disabled (the option exists but makes no sense for a macOS guest — separate-window mode is correct).

### Migration from the prior Mac

When the prior Mac's Parallels install is reachable (Time Machine, Migration Assistant target disk, network share), use Parallels' Transfer feature to bring VMs over. Fallback: copy the `.pvm` bundles directly from `~/Parallels/` on the source to `~/Parallels/` on the destination, then add them back via the Parallels Control Center.

If neither path is available (source is gone), rebuild from clean ISOs: Windows 11 ARM via Parallels' built-in download, macOS guest from a downloaded IPSW via `softwareupdate --fetch-full-installer`.

### Update channel

- Parallels' built-in updater controls upgrades. The Homebrew cask is intentionally not installed (per [ARCH-0014][14]); brew upgrade would race the in-app updater.
- Stay on the stable channel. Beta channel only when a beta-only feature is required.

### Consequences

- [+] Both VMs have predictable resources; the host stays responsive under multi-VM load
- [+] Coherence on Windows captures the user-facing value of Parallels' DirectX-to-Metal translation; Coherence off on macOS avoids the misfeature
- [+] Per-VM network mode lets the macOS guest become a LAN-reachable test target on demand without committing the Windows VM to bridged mode by default
- [+] Narrow shared folders reduce the attack surface compared to Parallels' wide default
- [+] Update path is unified through Parallels' own channel; no `brew upgrade` race
- [-] Pinned resource allocation must be revisited if the host's RAM ceiling changes or if a third VM is added
- [-] Migration paths assume the source Mac is reachable or that ISOs are available; a clean rebuild is a multi-hour exercise
- [-] Coherence misbehavior (one window failing to dock, mouse capture confusion) is a Parallels-specific debugging surface; OrbStack and Fusion users never see these classes of bugs

## More Information

- [ARCH-0014 Brewfile vs manual DMG criteria][14] — install path rationale
- [ARCH-0016 Virtualization stack][16] — when to install Parallels at all
- [Parallels KB: Apple Silicon resource recommendations][KB1]
- [Parallels KB: Configuring shared network and bridged network][KB2]

[14]: ARCH-0014%20Brewfile%20vs%20manual%20DMG%20criteria.md
[16]: ARCH-0016%20Virtualization%20stack.md
[KB1]: https://kb.parallels.com/en/124781
[KB2]: https://kb.parallels.com/en/128868
