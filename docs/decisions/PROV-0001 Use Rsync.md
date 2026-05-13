---
title: Use Rsync
description: Migration scripts use Homebrew's rsync explicitly; Apple's /usr/bin/rsync is openrsync 2.6.9-compatible and lacks modern flags
type: adr
category: tooling
tags:
    - rsync
    - homebrew
    - macos
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0002 New machine provisioning order.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Use Rsync

## Context and Problem Statement

macOS ships `/usr/bin/rsync` as `openrsync` (OpenBSD's reimplementation), identifying as "rsync 2.6.9 compatible" — Apple replaced GNU rsync to avoid GPLv3 in 2019. openrsync lacks rsync 3.x features including `--info=progress2` and many filter / partial / batch flags.

The first run of `claude-history.sh` used `rsync -a --info=progress2`; openrsync printed its usage text and silently transferred zero files. `brew install rsync` lands a modern binary at `/opt/homebrew/bin/rsync`, but `/usr/bin/rsync` shadows it in default PATH order. Homebrew prints a "shadowed" warning; scripts don't notice.

## Decision Drivers

- Migration scripts must work reliably without depending on shell PATH order
- Modern flags (progress reporting, partials, filters) matter for migrations larger than ~100 MB
- The brew dependency should be explicit in `manifests/Brewfile`
- The failure mode should be loud, not silent

## Considered Options

1. **Use only flags supported by openrsync 2.6.9** — works without brew dep; constrains scripts to a 2006-era feature set
2. **Fix shell PATH so `/opt/homebrew/bin` precedes `/usr/bin`** — global, benefits other tools, but is shell-environment level and not script-portable
3. **Call `/opt/homebrew/bin/rsync` explicitly in scripts** — script-local, no PATH dependency, makes the brew dep explicit
4. **Build rsync from source** — overkill; brew already provides what's needed

## Decision Outcome

Chosen option: **explicit `/opt/homebrew/bin/rsync` in migration scripts, `brew "rsync"` in Brewfile**. Apple Silicon path first, Intel fallback (`/usr/local/bin/rsync`) second, explicit fail if neither. The script never falls through to `/usr/bin/rsync` — the bug should be loud.

### Consequences

- [+] Modern rsync features unconditionally available
- [+] Dependency captured in `manifests/Brewfile` — reproducible
- [+] Failure mode is loud and actionable
- [-] Migration scripts depend on Homebrew being installed (acceptable — baseline anyway)
- [-] Pattern may repeat in other scripts needing modern rsync; could be factored into `scripts/lib/` later

## More Information

- [openrsync.org](https://www.openrsync.org/) — OpenBSD reimplementation Apple ships
- [Homebrew rsync formula](https://formulae.brew.sh/formula/rsync) — modern build used by migration scripts
