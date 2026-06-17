---
title: Discord official app with Little Snitch
description: Discord runs as the official desktop app, contained by Little Snitch at the network layer, rather than replaced by a third-party client. The official app carries a more-hardened supply chain than a single-maintainer wrapper. Little Snitch blocks separable telemetry and crash-reporting domains, but cannot strip Discord's in-API /api/science telemetry, which shares the discord.com host the app needs. Containment is network-only: process enumeration and filesystem reach are not contained short of a VM, and Discord's server-side data handling is unchanged.
type: adr
category: tooling
tags:
    - discord
    - little-snitch
    - firewall
    - chat
    - sandboxing
status: accepted
created: 2026-06-03
updated: 2026-06-03
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0030 Discord desktop app threat model.md"
    - "ARCH-0016 Virtualization stack.md"
    - "PROV-0007 Brewfile manifest.md"
    - "PROV-0013 Little Snitch rule strategy.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://discord.com/
    - https://www.obdev.at/products/littlesnitch/
---

# Discord official app with Little Snitch

## Context and Problem Statement

Discord is needed on the machine. [ARCH-0030][30] establishes that the official desktop app is untrusted *as an uncontained binary*: it enumerates running processes, ships native modules, self-updates by fetching and executing module archives, and sends client telemetry. There are two ways to act on that: replace the binary (a third-party client or the web app), or keep the binary and contain it.

Replacing the official app with a third-party client swaps Discord's funded, audited, fast-patched supply chain for a single-maintainer one (one person's Apple signing cert plus CI secrets, no reproducible builds, no audit) and adds a one-toggle on-ramp to arbitrary-code client mods, while fixing nothing about Discord's server-side data handling. For a supply-chain-centred threat model that is a sideways-to-downward move. The official app's supply chain is the part worth keeping; its local invasiveness is the part worth containing.

## Decision Drivers

- Keep the more-hardened official supply chain rather than trusting a hobbyist wrapper's signing key.
- Contain the official app's local invasiveness (telemetry, native modules, process scanning, updater blast radius) to the degree macOS allows a non-author to.
- Low enough friction to actually use daily; voice and screenshare must keep working.
- Be honest about scope: no client choice or host firewall changes Discord's server-side collection, retention, or law-enforcement disclosure ([ARCH-0030][30], Ground 2).

## Considered Options

1. **Official app, uncontained.** Rejected by [ARCH-0030][30].
2. **Third-party client (Legcord / Vesktop).** Rejected: trades the official hardened supply chain for a single-maintainer one, adds a mod on-ramp, and addresses nothing server-side. For the narrow goal of "no Discord native binary" it is dominated by the browser PWA.
3. **Browser PWA (discord.com/app).** Strongest containment, Discord runs inside the browser sandbox, zero new native code, telemetry blockable at the network layer. The only reason it is not chosen here is the preference for native-app ergonomics; it remains the recommended path if that preference lapses.
4. **Official app + Little Snitch (chosen).** Keeps the official supply chain, contains telemetry at the network layer with per-app per-domain rules.
5. **Official app in a VM (Parallels, [ARCH-0016][16]).** The only option that also contains process enumeration, filesystem reach, and updater blast radius. Reserved for when that containment matters more than voice and screenshare quality, which degrade in a VM.

The "dedicated macOS user account for Discord" was explicitly rejected as a half-measure: macOS lets any non-root process enumerate every user's processes, so it would not stop game detection while only appearing to isolate.

## Decision Outcome

Chosen: **Option 4, the official Discord app contained by Little Snitch**, with the **browser PWA recorded as the stronger-containment alternative** and a **VM ([ARCH-0016][16]) as the escalation** if process/filesystem containment becomes a requirement.

### Install

- Both are Homebrew casks in `manifests/Brewfile` ([PROV-0007][7]): `discord` and `little-snitch`, applied by `scripts/install/brew-bundle.sh`. Both are signed and notarized: Discord, Inc. (Team ID `53Q6R32WPB`) and Objective Development (Team ID `MLZF7K7B5R`).
- Little Snitch needs its system network extension approved in System Settings after install, and the **perpetual full license**, not the subscription-based Mini.

### Containment scope (what Little Snitch does and does not do)

- **Does (for Discord, almost nothing):** gives per-process visibility and lets the user deny any surprising host. But Discord has essentially no *separable* telemetry to block: `/api/v9/science` (aliased `/api/track`) and even its crash reporting (in-page Sentry, `window.DiscordSentry`) both ride `discord.com`, the host the app requires. A host firewall cannot separate a URL path from the host, and blocking `discord.com` breaks the app. So for Discord specifically, Little Snitch is visibility-only, not a telemetry blocker. (For *other* apps that ship a standalone Sentry SDK or distinct analytics host, Little Snitch does block those, see [PROV-0013][13].)
- **Does not:** strip same-host telemetry. The only full fix is the web client behind a path-aware blocker (uBlock filter `||discord.com^*/science`), not a network firewall.
- **Does not:** stop the app from enumerating running processes, reading files in the user's home, or limit the blast radius of its auto-updater. Those are host-isolation concerns that only a VM addresses (Option 5).
- **Does not:** change anything Discord collects server-side. Behavioural controls still apply: never submit a government ID for age verification, treat DMs as non-private, and do not make Discord the sole home of anything that matters.

### Why Little Snitch over alternatives

Little Snitch leads on per-domain wildcard rules, traffic visibility, and current macOS 26 / Apple Silicon maintenance. LuLu (free, open-source) now ties on the core per-domain capability and is the fallback if open-source-on-principle outweighs polish; its bulk-domain UI is cruder and it lacks the wildcard edge that helps with Discord's rotating CDNs.

### Consequences

- [+] Keeps Discord's funded, audited, fast-patched supply chain instead of a single-maintainer one.
- [+] Separable telemetry and crash-reporting domains are blocked at the network layer with tooling under the user's control; the app's connection set is visible and deniable.
- [+] No Terms-of-Service exposure (the official app is sanctioned), and no client-mod on-ramp.
- [+] An escalation path exists (VM) without re-litigating the client choice.
- [-] Little Snitch contains only the network layer; process enumeration and filesystem reach remain until/unless Discord runs in a VM.
- [-] Discord's server-side data handling is untouched; this decision does not address it.
- [-] Little Snitch is paid, and its rule set needs occasional tending as Discord shifts telemetry hosts.
- [-] The official Electron app is heavier than the web client and self-updates; updates are accepted on Discord's cadence rather than pinned.

## More Information

- [ARCH-0030 Discord desktop app threat model][30] — why the official app is untrusted uncontained, and why Tencent is not the argument
- [ARCH-0016 Virtualization stack][16] — the VM escalation path
- [PROV-0007 Brewfile manifest][7] — where the casks are declared
- [PROV-0013 Little Snitch rule strategy][13] — how blocklists and allow rules are managed
- [Little Snitch][LS]

[30]: ARCH-0030%20Discord%20desktop%20app%20threat%20model.md
[16]: ARCH-0016%20Virtualization%20stack.md
[7]: PROV-0007%20Brewfile%20manifest.md
[13]: PROV-0013%20Little%20Snitch%20rule%20strategy.md
[LS]: https://www.obdev.at/products/littlesnitch/
