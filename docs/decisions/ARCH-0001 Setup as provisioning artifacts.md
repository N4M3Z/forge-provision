---
title: Setup as provisioning artifacts
description: Every mutating command during machine setup becomes a script in forge-provision/scripts/ or a journal entry — recorded as-it-happens
type: adr
category: architecture
tags:
    - provisioning
    - reproducibility
    - working-principle
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related: []
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Setup as provisioning artifacts

## Context and Problem Statement

Fresh-Mac setup traditionally produces nothing reproducible. Shell commands, System Settings clicks, app installs — the only evidence afterward is the configured machine itself. The next Mac arrives and the work happens again ad-hoc, slightly different each time, with no record explaining *why* any step was taken. The agentic-first goal collapses without persistent artifacts: the next Mac cannot self-provision if every step lives in someone's head.

## Decision Drivers

- The next Mac's setup should be invocable, not reconstructed from memory
- *Why* each step exists must persist alongside *what* was done
- Recording must happen during the work, not retroactively
- Recording overhead must be small enough not to slow the work itself

## Considered Options

1. **Ad-hoc shell + memory** — status quo before forge-provision; fails the reproducibility goal
2. **Docs-only** (descriptive prose, e.g. mac-setup Docusaurus) — captures *what to do* but not *what was done*; goes stale; not executable
3. **Dotfiles-only** — captures files that land in `$HOME` but not system mutations (`defaults write`, `brew install`); partial
4. **Hybrid: scripts + journal** — each mutating action becomes either a script (idempotent, reusable) in `scripts/<verb>/<noun>.sh`, or a journal entry (narrative, dated) in `journal/YYYY-MM-DD.md`. ADRs crystallize stable decisions out of journal context. Git log is the chronological index.

## Decision Outcome

Chosen option: **hybrid scripts + journal**. Rule: every mutating command during setup gets written down — as it happens, not retroactively. Pure exploration (`ls`, `cat`, `find`, `grep`, `which`, `defaults read`) is research, not setup; it stays in conversation. Mutating commands (`brew install`, `defaults write`, file moves, `rsync`, `git clone`, `chmod`) become scripts or journal entries.

Confirmation pattern: before running a mutating command, ask. Even a dry-run signals action that must be aligned on first. Default workflow: propose, confirm, then act.

### Consequences

- [+] Provisioning repo grows organically from the work itself; no separate documentation effort
- [+] Re-running on a fresh Mac is deterministic
- [+] Journal entries provide *why*, not just *what*
- [+] ADRs extract crystallized decisions from journal context as they stabilize
- [-] Small overhead per setup action — capture before running, not after
- [-] Pure-exploration vs setup boundary is sometimes blurry

## More Information

- `forge-provision/CLAUDE.md` — the agentic scaffold codifying this principle for Claude Code sessions in the repo
- `forge-provision/journal/2026-05-10.md`, `2026-05-11.md` — applied examples
