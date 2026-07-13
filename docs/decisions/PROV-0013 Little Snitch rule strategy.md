---
title: Little Snitch rule strategy
description: Deny is handled by Little Snitch's built-in blocklist subscriptions (reputable publishers, auto-updating), never hand-written deny rules or a single stranger's GitHub list. Allow is handled by Alert Mode for Homebrew CLI tools and GUI apps (Little Snitch resolves their identity at approval time), plus a small hand-drafted baseline of stable-path system tools tracked in the repo and deployable to dotfiles. Silent Mode only observes; it does not create rules.
type: adr
category: security
tags:
    - little-snitch
    - firewall
    - blocklists
    - allow-rules
    - dotfiles
status: accepted
created: 2026-06-03
updated: 2026-06-03
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0011 Discord official app with Little Snitch.md"
    - "ARCH-0005 Dotfiles engine chezmoi.md"
    - "ARCH-0008 Config home dotfiles vs provisioning.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://help.obdev.at/littlesnitch6/concepts-opmodes
    - https://help.obdev.at/littlesnitch6/lsc-rule-group-subscriptions
---

# Little Snitch rule strategy

## Context and Problem Statement

[PROV-0011][11] adopts Little Snitch. This ADR fixes *how its rules are managed*, split into two unrelated problems: deny (blocklists) and allow (per-app rules).

Two facts shape the design. First, blocklists evolve endlessly, so any static list rots, and the maintained ones (Hagezi, OISD, abuse.ch, Peter Lowe) are continuous projects, not a single person's repo, so depending on a random GitHub `.lsrules` is both stale and a standing single-maintainer trust relationship. Second, Little Snitch's **Silent Mode (Allow) only observes**: it logs every connection in Network Monitor but does not persist rules. Rules are created in Alert Mode or by hand. An approach that assumed silent mode would "learn" a rule set was wrong.

A third constraint surfaced empirically: Homebrew CLI binaries are symlinks into versioned `Cellar` paths (`node` resolves to `Cellar/node/26.0.0/...`). The kernel reports both the `/opt/homebrew/bin` symlink and the resolved `Cellar` path, and which one Little Snitch keys a rule on is not determinable without watching a live match. So hand-authoring path-based rules for Homebrew tools risks silent breakage on every `brew upgrade`.

## Decision Drivers

- Blocklists must auto-update from reputable maintainers, with no dependency on one stranger's repo and no hand-maintained deny rules.
- Allow rules must be reproducible and portable (tracked, redeployable on a fresh machine).
- Avoid alert fatigue, and avoid fragile rules that break on routine upgrades.
- Keep the right tool at the right layer: a 100k-domain blocklist is a subscription/DNS concern, not a per-process firewall rule set.

## Considered Options

### Deny (blocklists)

1. **Hand-written deny rules.** Rejected: unmaintainable against an evolving target.
2. **Third-party GitHub `.lsrules` subscription.** Rejected: the community lists are years stale, and a live subscription is a standing auto-update trust relationship with one maintainer.
3. **Self-hosted `.lsrules` pipeline** (own repo regenerates from upstreams). Viable and owned, but adds a pipeline to maintain and pushes a 100k-domain list into a host firewall, the wrong layer.
4. **Little Snitch built-in blocklist subscriptions.** Curated by Objective Development from reputable publishers (Peter Lowe, AdAway, URLhaus/abuse.ch), deny-only, auto-updating in the background.
5. **DNS layer** (NextDNS, AdGuard Home + Hagezi/OISD). The architecturally-correct home for huge evolving lists; complements rather than replaces.

### Allow (per-app rules)

A. **Silent-Allow auto-learning.** Rejected: silent mode observes, it does not create rules.
B. **Alert Mode.** Little Snitch resolves a process's identity at approval time and re-prompts if it changes, robust for Homebrew CLI tools and GUI apps whose paths churn.
C. **Hand-drafted baseline.** A small set of deliberate allow rules for stable-path system tools, tracked and portable.

## Decision Outcome

### Deny: built-in blocklist subscriptions (Option 4), optionally DNS (Option 5)

Enable a conservative, low-false-positive set from Little Snitch's built-in catalog: AdAway and Peter Lowe (ads/trackers), URLhaus (malware). These auto-update from their publishers with nothing to maintain. If a larger, always-fresh blocklist is wanted, it belongs at the DNS layer (NextDNS or self-hosted AdGuard Home subscribed to Hagezi/OISD), with Little Snitch's DNS encryption pointed at that resolver, not as Little Snitch rules.

### Allow: Alert Mode (Option B) plus a stable-path baseline (Option C)

- Run Alert Mode for the long tail: Homebrew CLI tools (`node`, `bun`, `cargo`, `python3`, `gh`), GUI apps, and anything whose identity Little Snitch should resolve itself. npm/pip/cargo connect *as* those Homebrew tools (not the shell), so they are Alert-Mode territory by design.
- Keep the factory Apple/system rule groups permissive so updates, iCloud, and the App Store keep working.
- Track a small hand-drafted baseline at `manifests/littlesnitch/dev-allow.lsrules`: narrow allow rules for stable-path system tools (`/usr/bin/git`, `/usr/bin/curl`, `/usr/bin/ssh`) reaching known source and package hosts (GitHub, Homebrew, npm, PyPI, crates). These paths never move, so the rules are durable. Import it into a dedicated rule group; deploy to a fresh machine via chezmoi ([ARCH-0005][5]) and re-import.

### Workflow

Silent Mode (Allow) for an initial observation window to populate Network Monitor, design rules from what it shows, then switch to Alert Mode. Never bake Homebrew `Cellar` paths into the tracked `.lsrules`.

### Consequences

- [+] Blocklists stay fresh from reputable publishers with zero maintenance and no dependence on a single stranger's repo.
- [+] Allow rules are robust: stable-path tools are pinned in a tracked file; churny tools are resolved by Little Snitch at approval time instead of by a fragile hard-coded path.
- [+] The portable baseline reproduces on a new machine via dotfiles; the rest rebuilds quickly under Alert Mode.
- [+] Each concern sits at the right layer (subscription/DNS for bulk deny, per-process firewall for allow).
- [-] The hand-drafted baseline is deliberately small; most per-app rules are rebuilt per machine under Alert Mode rather than fully restored from dotfiles.
- [-] Built-in blocklists are still third-party publishers (deny-only, curated by Objective Development, but a trust relationship nonetheless).
- [-] A genuinely comprehensive blocklist requires standing up the DNS layer, which is additional setup not covered here.

## More Information

- [PROV-0011 Discord official app with Little Snitch][11] — the install and threat context
- [ARCH-0005 Dotfiles engine chezmoi][5] — how the baseline `.lsrules` deploys
- [ARCH-0008 Config home dotfiles vs provisioning][8] — where config lives
- [Little Snitch operation modes][OPMODES]
- [Little Snitch rule group subscriptions][SUB]

[11]: PROV-0011%20Discord%20official%20app%20with%20Little%20Snitch.md
[5]: ARCH-0005%20Dotfiles%20engine%20chezmoi.md
[8]: ARCH-0008%20Config%20home%20dotfiles%20vs%20provisioning.md
[OPMODES]: https://help.obdev.at/littlesnitch6/concepts-opmodes
[SUB]: https://help.obdev.at/littlesnitch6/lsc-rule-group-subscriptions
