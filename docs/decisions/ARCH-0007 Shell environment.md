---
title: Shell environment
description: zsh + Prezto (kept) + starship (prompt, tokyo-night preset) + atuin (history with substring-on-Up); ccline as Claude Code statusline
type: adr
category: architecture
tags:
    - shell
    - zsh
    - prompt
    - history
    - claude-code
status: accepted
created: 2026-05-13
updated: 2026-05-13
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0005 Dotfiles engine chezmoi.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Shell environment

## Context and Problem Statement

The new Mac's shell setup needs to deliver "spin up new terminal, history available, prompt working" within seconds of cloning dotfiles. The old Mac used Prezto + powerlevel10k + GNU stow. With chezmoi taking over dotfile laydown (ARCH-0005), the remaining choices are: shell framework, prompt, history search/sync, and Claude Code statusline.

## Decision Drivers

- "Spin up new terminal fast" — no manual setup, no history merging
- Agentic-first: config readable without framework-specific knowledge
- Mature, maintained, popular components
- Render speed at the prompt (every shell open + every preexec hits this)
- History available across machines, with substring-search-on-Up-arrow as the canonical search

## Considered Options

1. **Vanilla `.zshrc` + zsh-defer + brew plugins** — most agentic-friendly; user found zsh-defer "ancient" and chose familiarity over micro-optimization
2. **antidote / zim / zinit** — modern frameworks; user has stable Prezto setup, doesn't need dynamic plugin loading
3. **Prezto + starship + atuin** — chosen
4. **Prezto + oh-my-posh + atuin** — richer theme catalog and native transient-prompt, but render is 5–10x slower than starship (~40–130ms vs ~5–10ms), JSON theme files are ~3x longer than starship TOML, and color quantization on `xterm-256color` makes custom Tokyo Night palette JSONs less predictable in practice
5. **oh-my-zsh** — user dislikes the framework feel

## Decision Outcome

Chosen option: **Prezto (kept) + starship (prompt) + atuin (history, default-local) + `@cometix/ccline` (Claude Code statusline)**. Prezto handles framework duties (modular config, plugin bundling, sensible setopts). starship replaces Prezto's prompt module via Prezto's `prompt` theme set to `off`. Active preset is the official `tokyo-night` from starship's bundled gallery (`starship preset tokyo-night -o ~/Developer/N4M3Z/dotfiles/config/starship.toml`), deployed via chezmoi to `~/.config/starship.toml` and loaded via `eval "$(starship init zsh)"`. Theme swaps are one `starship preset <name>` plus a chezmoi apply. atuin replaces both `Ctrl-R` (fuzzy TUI search) AND zsh-history-substring-search: `~/.config/atuin/config.toml` sets `search_mode_shell_up_key_binding = "fulltext"` so Up arrow does substring-on-Up matching against atuin's SQLite, which mirrors `.zhistory` via a preexec hook. atuin runs default-local (no sync server, no account); sync can be enabled later. `@cometix/ccline` (Rust binary distributed via npm/bun) replaces Claude Code's default statusline; configured via `~/.claude/settings.json` `statusLine.command`. Installed via `bun install -g` (see PROV-0004). ccline config at `~/.claude/ccline/config.toml` shows Model | Directory | Git branch | Context window.

### Consequences

- [+] Familiar Prezto behavior survives; zero migration tax on the shell-config side
- [+] starship render is ~5–10ms, imperceptible on every preexec
- [+] TOML config is short and readable; the official tokyo-night preset matches the ccline statusline palette family
- [+] One tool (atuin) covers both `Ctrl-R` and Up-arrow substring search — single source of truth
- [+] Default-local atuin = no external service dependency until sync is explicitly enabled
- [-] zsh transient prompt requires the `olets/zsh-transient-prompt` plugin (starship issue #888 has been open since 2020)
- [-] starship has 12 official presets versus 122 in oh-my-posh; community gists fill the gap but with no central registry
- [-] Prezto's prompt module is unused dead weight; tolerable given the framework's other modules

## More Information

- [starship](https://starship.rs/) — Rust prompt engine
- [starship presets gallery](https://starship.rs/presets/)
- [starship tokyo-night preset](https://starship.rs/presets/tokyo-night)
- [atuin](https://atuin.sh/) — SQLite history; `search_mode_shell_up_key_binding` docs
- [@cometix/ccline](https://github.com/Haleclipse/CCometixLine) — Claude Code statusline
- [Prezto](https://github.com/sorin-ionescu/prezto) — still maintained
