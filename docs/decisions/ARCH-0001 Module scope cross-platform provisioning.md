---
title: "Module scope: best-practice provisioning artifacts, cross-platform"
description: "forge-provision codifies best practices for provisioning developer machines on macOS, Linux, and Windows. Every mutating action lands as a script or journal entry, with the why crystallizing into ADRs over time."
type: adr
category: architecture
tags:
    - provisioning
    - reproducibility
    - working-principle
    - module-scope
    - best-practices
    - cross-platform
status: accepted
created: 2026-05-11
updated: 2026-05-24
author: "@N4M3Z"
project: forge-provision
related: []
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Module scope: best-practice provisioning artifacts, cross-platform

## Module Scope

forge-provision is the canonical home for **best practices around developer-machine provisioning and the surrounding tool ecosystem**. The output is a runnable, idempotent recipe for bringing a fresh machine to a configured baseline, plus the design rationale for every choice along the way.

The module covers:

- **Provisioning scripts** that mutate the host (install, configure, migrate) — idempotent, env-configurable, dry-run-aware.
- **Skills** (`skills/`) that capture best-practice knowledge about the tools we install (terminal multiplexers, shells, version managers, package managers, signing setups, etc.).
- **TLDRs** (`docs/tldrs/`) as the day-to-day reference for tools whose 80% path benefits from a curated one-pager.
- **ADRs** (`docs/decisions/`) that crystallize design decisions out of session narratives.
- **Rules** (`rules/`) that encode the conventions the scripts and skills must follow.
- **Journals** (`docs/journal/`) that record what landed and why, dated.

The module provisions **macOS, Linux, and Windows** developer machines. Platform-specific scripts live under `scripts/install/<platform>/`, `scripts/configure/<platform>/`, and so on, with `scripts/lib/` helpers handling OS dispatch. Skills and TLDRs that are platform-agnostic stay at the top level; platform-specific ones get an OS suffix or live under a platform-named subdirectory.

The module is **opinionated** — every script reflects a particular best-practice choice the author has converged on through use. Alternatives discussed and rejected belong in ADRs, not in inline comments inside scripts. Skills should provide options, configuration, and expertise oriented toward the chosen path; landscape surveys ("tmux vs zellij", "Ghostty vs WezTerm") belong in ADRs, not in skill bodies.

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
