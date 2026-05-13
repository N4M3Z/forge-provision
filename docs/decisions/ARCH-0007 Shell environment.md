---
title: Shell environment
description: zsh + Prezto (kept) + starship (prompt) + atuin (history with substring-on-Up); ccline as Claude Code statusline
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
- History available across machines, with substring-search-on-Up-arrow as the canonical search

## Considered Options

1. **Vanilla `.zshrc` + zsh-defer + brew plugins** — most agentic-friendly; user found zsh-defer "ancient" and chose familiarity over micro-optimization
2. **antidote / zim / zinit** — modern frameworks; user has stable Prezto setup, doesn't need dynamic plugin loading
3. **Keep Prezto + add starship + atuin** — minimal migration tax; user knows Prezto; starship overrides Prezto's prompt module (acceptable redundancy)
4. **oh-my-zsh** — user dislikes the framework feel

## Decision Outcome

Chosen option: **Prezto (kept) + starship (prompt) + atuin (history, default-local) + `@cometix/ccline` (Claude Code statusline)**. Prezto handles framework duties (modular config, plugin bundling, sensible setopts). starship replaces Prezto's prompt module via Prezto's `prompt` config set to `off` (or leave Prezto's prompt loaded and let starship override). atuin replaces both `Ctrl-R` (fuzzy TUI search) AND zsh-history-substring-search: `~/.config/atuin/config.toml` sets `search_mode_shell_up_key_binding = "fulltext"` so Up arrow does substring-on-Up matching against atuin's SQLite, which mirrors `.zhistory` via a preexec hook. atuin runs default-local (no sync server, no account); sync can be enabled later. `@cometix/ccline` (Rust binary distributed via npm/bun) replaces Claude Code's default statusline; configured via `~/.claude/settings.json` `statusLine.command`. Installed via `bun install -g` (see PROV-0004). ccline config at `~/.claude/ccline/config.toml` shows Model | Directory | Git branch | Context window.

### Consequences

- [+] Familiar Prezto behavior survives; zero migration tax on the shell-config side
- [+] starship gives a fast, cross-shell prompt without abandoning Prezto's other modules
- [+] One tool (atuin) covers both `Ctrl-R` and Up-arrow substring search — single source of truth
- [+] Default-local atuin = no external service dependency until sync is explicitly enabled
- [-] Prezto's prompt module is unused dead weight; tolerable given the framework's other modules
- [-] atuin is one more daemon-free Rust tool to install + maintain; failure mode is degraded search, not lost history (.zhistory still works)

## More Information

- [starship](https://starship.rs/) — Rust prompt
- [atuin](https://atuin.sh/) — SQLite history sync; `search_mode_shell_up_key_binding` docs
- [@cometix/ccline](https://github.com/Haleclipse/CCometixLine) — Claude Code statusline
- [Prezto](https://github.com/sorin-ionescu/prezto) — still maintained (commits 2026-04)
