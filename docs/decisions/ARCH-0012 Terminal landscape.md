---
title: Terminal landscape
description: Map of the macOS terminal emulator landscape circa 2026 — classical, GPU-rendered, AI-augmented. Records the current pick (Ghostty + cmux), what's no longer in the running (Terminal.app, iTerm2), and what stays installed for comparison (Wave, Warp).
type: adr
category: tooling
tags:
    - terminal
    - emulator
    - landscape
    - survey
status: accepted
created: 2026-05-21
updated: 2026-05-21
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0010 Primary terminal emulator Ghostty.md"
    - "ARCH-0011 cmux as agent overlay on libghostty.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Terminal landscape

## Context and Problem Statement

The macOS terminal-emulator landscape circa 2026 has fractured into three families: classical (Apple Terminal, iTerm2), GPU-rendered minimal (Alacritty, kitty, WezTerm), and AI-augmented (Warp, Wave, Ghostty, cmux). Each family optimizes for different things — feature surface vs raw speed vs agent integration.

[ARCH-0010](ARCH-0010 Primary terminal emulator Ghostty.md) settles the daily-driver choice (Ghostty + libghostty); [ARCH-0011](ARCH-0011 cmux as agent overlay on libghostty.md) settles the agent-overlay choice (cmux). This ADR records the broader landscape: what's the current cohort, what's ancient, what stays installed for comparison, and what would trigger a re-evaluation.

## Decision Drivers

- Native macOS feel vs cross-platform parity
- GPU rendering for sustained text emission under heavy AI / build output
- AI integration that pulls weight beyond what Claude Code already provides
- License and update model (FOSS vs paid SaaS vs vendor-CDN)
- Coexistence with the chosen daily driver (no conflicts, install size, app-switching overhead)

## The current cohort

### Adopted

| Tool      | Role                                                        | Where                                                |
| --------- | ----------------------------------------------------------- | ---------------------------------------------------- |
| **Ghostty** | Primary terminal emulator                                  | `cask "ghostty"` in `manifests/Brewfile`             |
| **cmux**  | Agent-first overlay on libghostty for multi-Claude workflows | `scripts/install/cmux.sh` (DMG, intentionally not cask) |

### Installed for comparison

| Tool    | Why kept installable                                                                          | Where                            |
| ------- | --------------------------------------------------------------------------------------------- | -------------------------------- |
| **Wave** | Open-source (Apache 2.0). Graphical blocks (inline images, embedded HTML, DB browser plugin). Worth a comparison run if a graphical-blocks workflow appears. | `manifests/Brewfile.optional`    |
| **Warp** | Rust-rendered, blocks UI. AI tier is paid and overlaps Claude Code Max — re-evaluate if Warp opens up the agent surface. | `manifests/Brewfile.optional`    |

### Apple-shipped fallback

| Tool                  | Why                                                                |
| --------------------- | ------------------------------------------------------------------ |
| **Apple Terminal.app** | Default macOS terminal. AppleScript bridge target (see [PROV-0002](PROV-0002 macOS Terminal profile.md)). No-config emergency fallback. |

## No longer in the running

### iTerm2

iTerm2 is ancient technology — Objective-C, CPU-rendered by default (the Metal renderer is opt-in and behind a setting), plugin-via-features model where the app bundles its own multiplexer, FTP, profile system, theme system, scripting layer. The accumulated feature surface drags input latency at 15pt+ font sizes. No `display-p3` colorspace for Apple Silicon Retina rendering. GPL-2 licensed.

The whole iTerm2 value proposition predates the GPU-rendered-with-kitty-protocol generation; what it offered (tabs, splits, search, hotkey window, themes, profiles) is now table-stakes for any contender.

**Not installed.** Mentioned here so a future session looking at the landscape understands the explicit drop, not a missing entry.

### Cross-platform GPU minimals

| Tool      | Why not in the running                                                                                                                                          |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alacritty | No tabs, no scrollback search beyond `vi mode`. Pairs with tmux mandatorily. Loses to Ghostty on macOS-native chrome (no display-p3, no quick-terminal, no native blur). |
| kitty     | GPU + kitty-protocol authors, ligatures, image protocol. **GPL-3** is acceptance-blocking for some downstream apps. Python config DSL is divisive.               |
| WezTerm   | Rust + Lua config, multiplexer built in. Rich feature surface; Lua config heavyweight for the use case. Loses on simplicity (one tool per concern).             |

All three are functionally capable. None offers cmux-style workspace management, and pairing them with cmux is incoherent because cmux is built on libghostty specifically.

## Decision Outcome

**Ghostty + cmux as primary**, Wave and Warp parked in `manifests/Brewfile.optional` for occasional comparison runs, Apple Terminal kept as system fallback, iTerm2 dropped.

The primary `manifests/Brewfile` stays focused on the daily driver. `manifests/Brewfile.optional` is a separate file (`brew bundle install --file=manifests/Brewfile.optional`) holding the evaluation cohort with tombstone-style comments per entry explaining why they're not in the primary.

## Re-evaluation cadence

Yearly review of:

- Ghostty 1.x → 2.x major version or regressions
- cmux's libghostty version drift vs Ghostty
- Warp opening up its agent surface (free tier covering load-bearing AI features)
- Wave switching off Electron / gaining GPU rendering
- A new entrant in the libghostty-based-AI-terminal space

If a load-bearing reason emerges (e.g., Warp ships an open-source agent layer that beats cmux on multi-Claude ergonomics), revisit the choice. Otherwise the landscape is stable.

### Consequences

- [+] Wave and Warp stay installable via `brew bundle install --file=manifests/Brewfile.optional` for one-command comparison runs
- [+] The primary Brewfile stays focused on the daily driver
- [+] iTerm2 drop frees a Brewfile slot and removes a Metal-vs-non-Metal config concern
- [-] Wave/Warp installs become stale between comparison runs; cask updates only happen on `brew bundle install --file=manifests/Brewfile.optional`
- [-] Subjective comparisons are hard to maintain over time without a clear benchmark; relies on perception

## More Information

- [`manifests/Brewfile.optional`](../../manifests/Brewfile.optional) — Wave and Warp entries with rationale
- [GhosttyToolkit skill](../../skills/GhosttyToolkit/SKILL.md)
- [Warp Terminal](https://www.warp.dev/), [Wave Terminal](https://www.waveterm.dev/)
- [Alacritty](https://alacritty.org/), [kitty](https://sw.kovidgoyal.net/kitty/), [WezTerm](https://wezterm.org/) — cross-platform GPU minimals
