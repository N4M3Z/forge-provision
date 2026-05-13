---
title: New machine provisioning order
description: Deterministic sequence for taking a fresh Mac from Apple Setup Assistant to a productive agentic-first state
type: adr
category: architecture
tags:
    - provisioning
    - bootstrap
    - sequencing
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0001 Setup as provisioning artifacts.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# New machine provisioning order

## Context and Problem Statement

A fresh Mac starts at Apple Setup Assistant. Every transition has historically been ad-hoc shell + memory. Without a documented sequence, every machine is set up differently. The agentic-first goal is to hand off to Claude Code as soon as the OS has a sane baseline — but the order in which the foundational pieces (shell, dotfiles, package manager, Claude, forge) get installed matters.

## Decision Drivers

- Reproducibility — the next Mac follows the same sequence
- Honest cold-boot — nothing carries from an old Mac without explicit intent
- Each step is either a script or a deliberate manual checkpoint
- Tools that depend on other tools come later (shell + dotfiles before agentic deployment)

## Considered Options

1. **Ad-hoc shell + memory** — status quo, no reproducibility
2. **Migration Assistant full transfer** — Apple's flow; brings stale state into a "new" machine
3. **Documented sequence backed by forge-provision scripts** — explicit ordering, selective migration as a sub-step

## Decision Outcome

Chosen option: **documented sequence**. Canonical order — dotfiles before Claude Code, because a working shell and per-user config is foundational to comfortably *using* Claude. Migration from an old Mac, when applicable, is opinionated: only chat history and user-authored top-level instructions carry over; everything else is rebuilt cleanly via forge.

| #  | Step                                  | Script / note                                                                        |
| -- | ------------------------------------- | ------------------------------------------------------------------------------------ |
| 1  | Apple Setup Assistant                 | User-driven; not scripted                                                            |
| 2  | macOS defaults baseline               | `scripts/configure/macos-defaults.sh` (drduh-derived; DDM-managed keys may no-op)    |
| 3  | Install Xcode CLT + Homebrew          | `scripts/install/xcode-cli.sh`, `scripts/install/brew.sh`                            |
| 4  | Dotfiles                              | chezmoi (ARCH-0005). Shell + prompt + per-user config land first                     |
| 5  | Install Claude Code                   | `scripts/install/claude-code.sh`                                                     |
| 6  | Bootstrap forge-provision             | git clone or unpack the repo                                                         |
| 7  | Install forge-cli + deploy forge-core | `scripts/install/forge.sh`, `scripts/configure/forge-deploy.sh` (ARCH-0004)          |
| 8  | Selective migration (if applicable)   | `scripts/migrate/claude-history.sh`, `scripts/migrate/claude-instructions.sh`        |
| 9  | Auth                                  | SSH key (YubiKey where possible), git identity, `gh`                                 |
| 10 | Apps + tooling                        | `scripts/install/brew-bundle.sh`, `mas list` for App Store                           |
| 11 | Verify                                | `check-mac` + manual smoke tests                                                     |

**Deviation in this initial bootstrap** (2026-05-10 → 2026-05-11): Claude Code was installed before dotfiles. The canonical order puts dotfiles first; we inverted them here because the user needed to start the agentic-first development of `forge-provision` itself — Claude Code had to be available before any forge-* work, and dotfiles migration is one of those forge-* workstreams. Future provisions follow the canonical order; this iteration is documented as an exception, not a precedent.

### Consequences

- [+] Sequence is reproducible and observable from `journal/` history
- [+] Dotfiles-before-Claude order gives Claude sessions a properly configured shell from the start
- [+] Migration is selective by default — works for both "old Mac present" and "no old Mac" starting states
- [-] Steps 1 and 9 require user interaction (browser sign-ins, hardware tokens) and aren't fully automatable
- [-] Sequence will evolve as conventions stabilize

## More Information

- [drduh/macOS-Security-and-Privacy-Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide) — policy reference for step 2
- [N4M3Z/check-mac](https://github.com/N4M3Z/check-mac) — verifier for step 11
