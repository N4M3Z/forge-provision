---
title: Brewfile vs manual DMG criteria
description: Rapid-ship apps where unattended brew upgrade is unsafe (cmux today, possibly future Cursor channel) live as scripts/install/<app>.sh + Brewfile tombstone. Stable apps live as Brewfile casks.
type: adr
category: tooling
tags:
    - homebrew
    - dmg
    - install
    - cask
    - cmux
    - upgrade
status: accepted
created: 2026-05-21
updated: 2026-05-21
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0001 Module scope cross-platform provisioning.md"
    - "ARCH-0011 cmux as agent overlay on libghostty.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Brewfile vs manual DMG criteria

## Context and Problem Statement

The default install path for macOS apps is Homebrew cask (`cask "<name>"` in `manifests/Brewfile`). It's idempotent, declarative, and `brew bundle install` makes a fresh Mac match the manifest with one command. The catch: `brew upgrade` (or `brew bundle install` on a machine where the cask was already upgraded by another path) will silently overwrite an existing `.app` with whatever the cask currently points at — usually the latest release.

For stable, semver-disciplined apps (Visual Studio Code, Ghostty 1.x, Obsidian) this is what you want. For rapid-ship apps where the latest release ships breaking changes weekly (cmux today, possibly Cursor channel releases) the silent overwrite destroys a known-good working setup with no warning. Worse, `brew uninstall --cask` removes the `.app` itself, not just metadata, which makes a "let me detach from brew briefly" operation destructive (see the cmux incident, 2026-05-21).

This ADR establishes the criteria for choosing between Brewfile cask and manual DMG install.

## Decision Drivers

- Recovering from a bad upgrade is expensive (re-install from DMG, rebuild config) — the cost is asymmetric: a controlled upgrade is cheap, an uncontrolled one is expensive
- `brew bundle install` should be safe to re-run on any machine, any time
- A fresh Mac should still install everything with one command — fragmenting the install paths fragments the provisioning surface
- Per-app install scripts (`scripts/install/<app>.sh`) carry their own maintenance cost
- The decision must survive multiple-machine setups — what's installed on machine A should reproduce on machine B

## Considered Options

1. **All apps via Brewfile cask.** Simplest manifest, single install command. Accepts the silent-overwrite risk for rapid-ship apps.
2. **All apps via manual DMG.** Maximum control, maximum maintenance. Loses Homebrew's lifecycle management for stable apps that work fine in cask.
3. **Hybrid by criteria.** Stable apps via cask, rapid-ship apps via `scripts/install/<app>.sh` with a Brewfile tombstone explaining the decision.

## Decision Outcome

Chosen option: **hybrid by criteria**. Stable apps via `cask "<name>"` in `manifests/Brewfile`. Rapid-ship apps via `scripts/install/<app>.sh` paired with a Brewfile tombstone comment at the app's natural sort position.

### Criteria: rapid-ship → manual DMG

An app belongs in `scripts/install/<app>.sh` (not Brewfile) if **two or more** of these apply:

- **Release cadence is weekly or faster** AND **upstream's release notes do not flag breaking changes reliably.**
- **`brew upgrade` running unattended** (e.g., from a scheduled `brew bundle install` in CI or a cron job) **would be unsafe.**
- **The cost of a regression is high** (loss of in-flight work, broken hooks, broken integrations with other tools that pinned to specific versions).
- **The app's own update mechanism** is preferred (in-app updater, channel-based releases that the user wants to opt into deliberately).

cmux meets all four — it's the canonical example. Future candidates: Cursor channel-of-the-week releases, Zed nightly, any AI-assist app that ships rapid revisions.

### Criteria: stable → Brewfile cask

An app belongs as `cask "<name>"` in `manifests/Brewfile` if:

- **Semver discipline** — major-version bumps signal breaking changes, point releases are safe
- **Multi-year-old project** with predictable cadence
- **`brew upgrade` running unattended is safe** — the worst case is "feature X now requires opt-in" not "saved layout deleted"

Examples in the current setup: Ghostty 1.x (stable major version), Visual Studio Code, Obsidian, Cursor (the standard release, not channel previews), Raycast.

### The pairing pattern

When an app moves from cask to manual DMG, **always** leave a tombstone comment in `manifests/Brewfile` at the app's natural sort position:

```ruby
# <app> — intentionally NOT installed via Homebrew. Reproduced on fresh
# Mac by `scripts/install/<app>.sh`, which curls the canonical-latest DMG
# from <github releases url> and drops <app>.app into /Applications.
# Rationale: <app> ships rapidly; we'd rather opt into upgrades manually
# than have `brew upgrade` overwrite a known-good version.
```

The tombstone is load-bearing. Without it, a future session sees no cask declaration and "fixes" it by adding `cask "<app>"`, which silently competes with the manual install. The comment makes the absence intentional and traceable.

See [DmgInstall](../../skills/DmgInstall/SKILL.md) for the canonical install-script pattern (curl + hdiutil + cp -R + codesign verify + symlink), and [HomebrewToolkit](../../skills/HomebrewToolkit/SKILL.md) for the destruction semantics of `brew uninstall --cask`.

### Consequences

- [+] `brew bundle install` stays safe to re-run unattended on any machine
- [+] Rapid-ship apps retain their controlled-update story without forfeiting reproducibility
- [+] Tombstone comments make the absence intentional — future sessions don't "fix" it back
- [+] Fresh-Mac install is still one command per category (`brew bundle install --file=manifests/Brewfile`, then loop `scripts/install/*.sh`)
- [-] Two install paths to maintain — the orchestrator (`provision.sh`) has to handle both
- [-] Manual DMG scripts carry their own maintenance load (URL format changes, mount-point quirks)
- [-] Criteria are qualitative — a borderline app (semver-disciplined but rapid release) requires a judgment call

## More Information

- [DmgInstall skill](../../skills/DmgInstall/SKILL.md) — the canonical install pattern
- [HomebrewToolkit skill](../../skills/HomebrewToolkit/SKILL.md) — bottle/cask/mas + destruction semantics
- [`manifests/Brewfile`](../../manifests/Brewfile) — primary install manifest with cmux tombstone block
- [`scripts/install/cmux.sh`](../../scripts/install/cmux.sh) — reference DMG installer
