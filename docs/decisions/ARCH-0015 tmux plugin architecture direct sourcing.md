---
title: "tmux plugin architecture: direct sourcing, no TPM"
description: Drop TPM (Tmux Plugin Manager) in favor of chezmoi externals for git cloning + direct run-shell sourcing of each plugin's entry script. Eliminates TPM's startup lag and maintenance-stalled dependency.
type: adr
category: tooling
tags:
    - tmux
    - tpm
    - plugins
    - chezmoi
    - performance
status: accepted
created: 2026-05-26
updated: 2026-05-26
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0005 Dotfiles engine chezmoi.md"
    - "ARCH-0009 Terminal multiplexer tmux.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# tmux plugin architecture: direct sourcing, no TPM

## Context and Problem Statement

TPM (Tmux Plugin Manager) was the standard way to manage tmux plugins: declare `set -g @plugin '...'` in tmux.conf, TPM discovers them, sources each `*.tmux` entry script at startup, and `prefix+I` installs new ones from GitHub.

Two problems surfaced during the ResearchCouncil investigation (2026-05-26):

1. **TPM itself is maintenance-stalled.** Last merged PR: 2023-02. [Issue #318][TPM318] explicitly asks "Is this abandoned?" No response from maintainers. The runner code works but carries unpatched issues and no forward development.

2. **Startup lag is documented and measurable.** [Issue #257][TPM257]: 8-10 second startup with just 3 plugins on tmux 3.3a. [catppuccin/tmux #258][CAT258]: catppuccin alone adds ~1s via TPM's discovery loop vs near-zero with a direct `run-shell`. The lag comes from TPM iterating all `@plugin` declarations, resolving paths, and conditionally cloning on every server start.

Meanwhile, chezmoi externals already handle the git cloning step declaratively. TPM's only remaining job is sourcing `*.tmux` entry scripts at startup, which tmux's native `run-shell` command does directly.

## Decision Drivers

- Eliminate measurable startup lag from TPM's plugin-discovery loop
- Remove dependency on a maintenance-stalled project
- Keep plugins declarative (chezmoi externals for the clone, tmux.conf for the source)
- Preserve the existing plugin set (resurrect, continuum, catppuccin) without disruption
- Make adding/removing plugins a two-line change (external + run-shell) instead of three (external + @plugin + run-shell)

## Considered Options

1. **Keep TPM as-is.** Accept the lag and maintenance risk. Familiar, but the problems only get worse as plugins accumulate.
2. **Drop TPM, keep chezmoi externals, source directly via `run-shell`.** Chezmoi clones the repos; tmux.conf sources each plugin's entry script by path. Zero-dependency, no discovery loop, no startup lag beyond the plugin's own init.
3. **Switch to a TPM alternative (tmpm, tpm2, etc.).** No credible maintained alternative exists in the ecosystem.
4. **Drop plugins entirely.** Loses resurrect/continuum (session persistence), catppuccin (theming), and fingers (hint-copy). Too much regression.

## Decision Outcome

Chosen option: **drop TPM, keep chezmoi externals, source directly via `run-shell`**.

### The pattern

**Clone** via `dotfiles/.chezmoiexternal.toml`:
```toml
[".config/tmux/plugins/tmux-resurrect"]
    type = "git-repo"
    url = "https://github.com/tmux-plugins/tmux-resurrect.git"
    refreshPeriod = "168h"
```

**Source** via `dot_config/tmux/tmux.conf`:
```tmux
run-shell '~/.config/tmux/plugins/tmux-resurrect/resurrect.tmux'
```

No `set -g @plugin`, no TPM runner, no `prefix+I`. `chezmoi apply` handles the clone; `tmux source-file` handles the load. Adding a plugin is a two-line change (one TOML block + one `run-shell` line).

### Plugin selection (as of 2026-05-26)

| Plugin | Status | Decision |
| --- | --- | --- |
| catppuccin/tmux | Active, healthy | **Keep** (theming) |
| tmux-resurrect | Functionally complete, stale maintainer | **Keep** (session persistence, no alternative) |
| tmux-continuum | Same as resurrect | **Keep** (auto-save, auto-restore) |
| tmux-fingers | Active, v2.6.2 (Feb 2026) | **Adopt** (hint-based copy, replaces abandoned tmux-thumbs) |
| sesh | Active, Go binary, v2.26.2 | **Adopt** via Brewfile (standalone session manager, not a tmux plugin) |
| display-popup bindings | Config-only, no plugin | **Adopt** (fzf session switcher, inline gitui, scratch shell) |
| tmux-thumbs | Abandoned (last release Mar 2023, 48 open issues) | **Reject** |
| tmux-floax | Sole maintainer (omerxx) flagging burnout | **Defer** until maintainer situation stabilizes |
| tmux-sessionx | Same maintainer as floax, overlaps sesh | **Reject** (sesh covers the use case as a standalone binary) |
| tmux-nerd-font-window-name | Low adoption (209 stars), `#()` lag risk | **Reject** |
| TPM | Maintenance-stalled, documented startup lag | **Drop** |

### Source order in tmux.conf

catppuccin must be sourced BEFORE any `@catppuccin_*` option that references module files (the include logic resolves only after the plugin is sourced). resurrect must be sourced BEFORE continuum (continuum layers on resurrect). fingers has no ordering dependency.

### Consequences

- [+] Eliminates TPM startup lag (documented 8-10s → near-zero for direct sourcing)
- [+] Removes dependency on a maintenance-stalled project
- [+] Two-line plugin add/remove (TOML external + run-shell line)
- [+] `chezmoi apply` on a fresh Mac is the only install step (no `prefix+I`)
- [-] No `prefix+U` for one-command plugin updates (must `chezmoi apply` to refresh)
- [-] Plugin version pinning requires the chezmoi `refreshPeriod` workaround (set to a year+)
- [-] If a plugin renames its entry script, the `run-shell` path breaks silently (tmux shows an error on source-file but doesn't prevent startup)

## More Information

- [TPM issue #318 — "Is this abandoned?"][TPM318]
- [TPM issue #257 — 8-10s startup lag][TPM257]
- [catppuccin/tmux issue #258 — 1s catppuccin-via-TPM overhead][CAT258]
- [TmuxToolkit skill](../../skills/TmuxToolkit/SKILL.md)
- [ARCH-0005 Dotfiles engine chezmoi](ARCH-0005 Dotfiles engine chezmoi.md) (externals pattern)
- [ARCH-0009 Terminal multiplexer tmux](ARCH-0009 Terminal multiplexer tmux.md)

[TPM318]: https://github.com/tmux-plugins/tpm/issues/318
[TPM257]: https://github.com/tmux-plugins/tpm/issues/257
[CAT258]: https://github.com/catppuccin/tmux/issues/258
