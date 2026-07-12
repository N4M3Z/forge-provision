---
title: Virtualization stack
description: OrbStack for Linux/containers, VMware Fusion (free) for occasional Windows, Parallels Desktop only on a concrete DirectX/Coherence wall
type: adr
category: tooling
tags:
    - virtualization
    - parallels
    - vmware
    - orbstack
    - utm
    - windows
    - linux
status: accepted
created: 2026-05-30
updated: 2026-05-30
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0014 Brewfile vs manual DMG criteria.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Virtualization stack

## Context and Problem Statement

Developers on Apple Silicon Macs commonly reach for Parallels Desktop as the default virtualization tool, trained by a decade of Parallels being the only polished option. The 2026 landscape is different: [VMware Fusion Pro is free for all users including commercial since November 2024][VMW], [OrbStack][ORB] dominates Linux VMs and containers with native Apple Silicon performance, and Apple's Virtualization.framework has become a usable substrate for lighter-weight wrappers like Tart and UTM.

The question is not "which VM is best?" but "what does this machine actually need?" A knowledge council convened on 2026-05-28 (WebResearcher, SystemArchitect, DocumentationWriter, TheOpponent) converged on a segmented answer rather than a single product pick. This ADR captures the decision so future sessions don't re-litigate it.

[ARCH-0014][14] governs HOW to install whichever tools we choose (Brewfile cask vs official DMG). This ADR governs WHEN to choose each.

## Decision Drivers

- The user does not need Windows daily — occasional access at most
- Linux dev environments and containers are a recurring need (handled by Docker today; OrbStack queued in BACKLOG)
- Parallels Desktop subscription ($100-150/yr) buys real engineering (DirectX-to-Metal translation, Coherence mode) but only matters for GPU-intensive Windows workloads
- Vendor risk: both Parallels (Corel) and Fusion (Broadcom) are acquisition-prone; a tool that survives corporate strategy shifts has long-term value
- Fresh Mac should not preemptively install paid virtualization software

## Considered Options

1. **Parallels Desktop as default.** Best polish, best Windows GPU support, best Coherence integration. ~$150/yr. The historical default for a reason; still wins for daily Windows use.
2. **VMware Fusion Pro (free) as default.** Same Virtualization.framework substrate. Free. Lacks competitive GPU translation and Coherence-equivalent. Broadcom acquisition left a documentation graveyard but the product itself works.
3. **UTM (free, QEMU-based) as default.** Open-source. Near-native ARM Windows performance via Hypervisor.framework. USB passthrough and shared folders require manual config. The user-controlled-future option.
4. **OrbStack only, no Windows VM tool.** Linux + containers covered. Windows access via remote desktop to a cloud VM when needed. Cheapest, but cuts off offline Windows work entirely.
5. **Segmented: OrbStack + Fusion + Parallels-on-demand.** OrbStack for Linux, VMware Fusion when Windows surfaces, upgrade to Parallels only on a concrete wall.

## Decision Outcome

Chosen option: **segmented stack (option 5)**.

- **Linux + containers**: [OrbStack][ORB]. Free for personal use. Native Apple Silicon performance, Rosetta-accelerated x86 Linux, lighter than Docker Desktop. Add to `manifests/Brewfile` when adopted (currently queued in `BACKLOG.md`).
- **Occasional Windows**: [VMware Fusion Pro][VMW] (free). Install on first need, not preemptively. Sufficient for Office, Visual Studio, browser-based workflows, anything not GPU-intensive. Install via `cask "vmware-fusion"` in `manifests/Brewfile.optional` once installed.
- **Heavy Windows (GPU, Coherence, daily use)**: [Parallels Desktop][PD]. Install only after hitting a concrete wall with Fusion. Install path: official DMG per [ARCH-0014][14], not `cask "parallels"` in Brewfile (Parallels has its own update mechanism + license activation that brew can't handle cleanly). Provision via `scripts/install/parallels.sh` when adopted.

The trigger for upgrading Fusion → Parallels is empirical, not theoretical: a Windows workload that Fusion either cannot run or runs unacceptably slowly, AND the workload is recurring (not a one-time task that could be offloaded to a cloud Windows instance).

### What about UTM, Tart, VirtualBuddy?

- **UTM**: kept as a fallback option in `manifests/Brewfile.optional` if any future need exceeds Fusion's free tier. Not the default because of manual-config friction on USB and shared folders.
- **Tart**: useful for CI/scripted macOS VMs but not for daily developer work. Outside this ADR's scope.
- **VirtualBuddy**: purpose-built for macOS-on-macOS testing. Outside this ADR's scope.

### Consequences

- [+] Fresh Mac does not preemptively install paid virtualization
- [+] OrbStack handles the actual recurring need (Linux + containers) for zero ongoing cost
- [+] VMware Fusion handles occasional Windows for zero ongoing cost
- [+] Parallels stays available as the escalation path, with a clear empirical trigger
- [+] Forward-compatible with vendor risk: if Broadcom monetizes Fusion or Corel raises Parallels prices, OrbStack stays untouched
- [-] Three potential tools to track instead of one (OrbStack, Fusion, possibly Parallels)
- [-] The user must consciously evaluate each Windows need against the Fusion-before-Parallels trigger, not default-purchase Parallels
- [-] Documentation friction with Fusion post-Broadcom is real and may cost developer-hours on edge cases
- [-] If Windows GPU work becomes frequent, Parallels' Coherence-and-DirectX value materializes and the segmented approach adds friction over just owning Parallels

## More Information

- [VMware Fusion free announcement (Broadcom, 2024-11-11)][VMW]
- [OrbStack pricing and personal-use terms][ORB]
- [Parallels Desktop product page][PD]
- [UTM (QEMU-based, free, open-source)][UTM]
- [The future of large files in Git is Git][TYLER] (unrelated, but the same Tyler Cipriani is a useful longitudinal source on dev tooling trends)
- [Apple Silicon virtualization constraints (Eclectic Light, 2026-04-29)][EL]
- Knowledge council convened 2026-05-28; transcript in session journal

[14]: ARCH-0014%20Brewfile%20vs%20manual%20DMG%20criteria.md
[VMW]: https://blogs.vmware.com/cloud-foundation/2024/11/11/vmware-fusion-and-workstation-are-now-free-for-all-users/
[ORB]: https://orbstack.dev/pricing
[PD]: https://www.parallels.com/products/desktop/
[UTM]: https://mac.getutm.app/
[TYLER]: https://tylercipriani.com/blog/2025/08/15/git-lfs/
[EL]: https://eclecticlight.co/2026/04/29/virtualisation-on-apple-silicon-macs-is-different/
