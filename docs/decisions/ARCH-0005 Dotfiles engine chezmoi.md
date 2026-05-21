---
title: "Dotfiles engine: chezmoi"
description: Use chezmoi as the dotfiles engine with local pass-store for secret resolution
type: adr
category: tooling
tags:
    - dotfiles
    - chezmoi
    - secrets
    - pass
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0002 New machine provisioning order.md"
    - "ARCH-0008 Config home dotfiles vs provisioning.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Dotfiles engine: chezmoi

## Context and Problem Statement

A fresh Mac needs a dotfiles strategy. Templating, secret resolution, and cross-platform support all matter. The goal is a single canonical repo with idempotent `apply`, with secrets resolved locally at apply-time rather than stored in a separate private repo.

## Decision Drivers

- Templating without inline shell logic
- Secret resolution at apply-time, not at-rest in a separate repo
- Local-first — day-to-day `apply` should not require a cloud round-trip
- Cross-platform from day one (macOS today, Linux possibly later)

## Considered Options

1. **GNU stow + side repo for secrets** — familiar, mature; no templating, secrets at-rest in a separate repo
2. **chezmoi + age** — fully offline; no biometric/hardware unlock UX
3. **chezmoi + 1Password CLI** — best ergonomics; proprietary cloud dependency
4. **chezmoi + Proton Pass CLI** — first-party chezmoi template integration; cloud-synced via Proton
5. **chezmoi + traditional `pass` (password-store, `~/.password-store/`)** — GPG-encrypted, fully local, chezmoi has a built-in `pass` template function
6. **chezmoi + `passage`** — age-based fork of pass; modern crypto, smaller ecosystem
7. **nix-darwin + agenix** — fully declarative; steep ramp, Anthropic recommends the native Claude Code installer over Nix-managed installs

## Decision Outcome

Chosen option: **chezmoi + traditional `pass`**. Local-first beats cloud round-trip for day-to-day apply. `pass` is mature, GPG-backed, integrated into chezmoi as a first-class template function, and lives at `~/.password-store/` with no daemon. Proton Pass CLI is held in reserve for the subset of secrets that genuinely need cross-machine sync; both can coexist. `passage` (age-based) is the migration target if GPG key management proves cumbersome.

Status: accepted; implementation deferred until core machine tooling is settled.

### Consequences

- [+] Local secrets always available — no network dependency for `chezmoi apply`
- [+] First-party chezmoi integration via the `pass` function
- [+] Templating enables clean per-machine variance
- [-] GPG key management overhead — `passage` is the escape hatch
- [-] Cross-machine secret sync needs a separate mechanism (Proton Pass CLI or `pass-git-helper`)
- [-] Migration cost from existing stow-based dotfiles

## More Information

- [chezmoi password-manager functions](https://www.chezmoi.io/reference/templates/password-manager-functions/pass/) — built-in `pass` template function
- [passwordstore.org](https://www.passwordstore.org/) — traditional pass
- [passage](https://github.com/FiloSottile/passage) — age-based pass fork
- [Proton Pass CLI](https://protonpass.github.io/pass-cli/) — reserved for cross-machine sync
