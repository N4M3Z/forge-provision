---
title: "Dotfiles engine: chezmoi (with externals for plugin/sub-repo management)"
description: Use chezmoi as the dotfiles engine with local pass-store for secret resolution. chezmoi externals replace git submodules and run_onchange scripts for plugin/sub-repo management (tmux plugins, etc.).
type: adr
category: tooling
tags:
    - dotfiles
    - chezmoi
    - secrets
    - pass
    - externals
    - plugins
status: accepted
created: 2026-05-11
updated: 2026-05-21
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0002 New machine provisioning order.md"
    - "ARCH-0008 Config home dotfiles vs provisioning.md"
    - "ARCH-0009 Terminal multiplexer tmux.md"
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

## Plugin and sub-repo management via chezmoi externals

Plugins that live as separate git repos (tmux plugins under `~/.config/tmux/plugins/`, vim/neovim plugin managers, theme repos) historically use one of three patterns:

1. **Git submodules** — declarative but friction-heavy (initialize, deinit, depth, sparse-checkout quirks)
2. **Plugin manager's own install command** (`prefix + I` for TPM) — imperative; a fresh Mac would have no plugins until you press the key
3. **`run_onchange_*.tmpl` scripts in chezmoi** — runs a shell script on apply; works but adds shell logic to the dotfiles tree

**chezmoi externals** is the chosen pattern. Declare each external repo in `dotfiles/.chezmoiexternal.toml`:

```toml
[".config/tmux/plugins/tpm"]
    type = "git-repo"
    url = "https://github.com/tmux-plugins/tpm.git"
    refreshPeriod = "168h"

[".config/tmux/plugins/tmux-resurrect"]
    type = "git-repo"
    url = "https://github.com/tmux-plugins/tmux-resurrect.git"
    refreshPeriod = "168h"
```

`chezmoi apply` clones each repo at first run and refreshes on the `refreshPeriod` interval (weekly default in the setup above). Plugin manager registration (e.g., TPM's `@plugin` lines in `tmux.conf`) still happens normally — only the clone step is taken out of TPM's hands.

Pin to a specific commit by setting `refreshPeriod = "8760h"` (one year). Pin to a specific tag/branch by adding `refs = "v1.2.3"` or `refs = "main"`.

The pattern generalizes to any plugin or sub-repo dependency: vim/neovim plugin managers, theme repos, font sets, shell-framework modules. See [ARCH-0009 Terminal multiplexer tmux](ARCH-0009 Terminal multiplexer tmux.md) for the load-bearing application (tmux plugins via externals) and [TmuxToolkit skill](../../skills/TmuxToolkit/SKILL.md) for the config-side recipe.

### Consequences (externals)

- [+] Plugin clones are declarative — fresh Mac gets all plugins from `chezmoi apply`
- [+] Refresh cadence is per-external — pin individual plugins long, refresh others weekly
- [+] No `run_onchange_*.tmpl` shell scripts in the dotfiles tree for plugin management
- [+] Works for any git URL (GitHub, GitLab, self-hosted)
- [-] TPM's `prefix + I` still works as a manual escape hatch; two paths to install plugins
- [-] Refresh happens on `chezmoi apply` — a long-deferred apply pulls many updates at once
- [-] No equivalent of submodule-style commit pinning by default (workaround: `refreshPeriod = "8760h"`)

## More Information

- [chezmoi password-manager functions](https://www.chezmoi.io/reference/templates/password-manager-functions/pass/) — built-in `pass` template function
- [chezmoi externals reference](https://www.chezmoi.io/reference/special-files-and-directories/chezmoiexternal-format/)
- [passwordstore.org](https://www.passwordstore.org/) — traditional pass
- [passage](https://github.com/FiloSottile/passage) — age-based pass fork
- [Proton Pass CLI](https://protonpass.github.io/pass-cli/) — reserved for cross-machine sync
