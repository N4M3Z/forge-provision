---
title: cmux as the agent-first overlay on libghostty
description: cmux (manaflow-ai/cmux) is the daily-driver terminal for multi-Claude workflows on top of libghostty. Ghostty stays for the macOS quick-terminal drop-down that cmux lacks. Both coexist by design.
type: adr
category: tooling
tags:
    - cmux
    - libghostty
    - terminal
    - claude-code
    - agentic
status: accepted
created: 2026-05-21
updated: 2026-05-21
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0010 Primary terminal emulator Ghostty.md"
    - "ARCH-0014 Brewfile vs manual DMG criteria.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# cmux as the agent-first overlay on libghostty

## Context and Problem Statement

Claude Code workflows generate multiple parallel sessions per repo (review while implementing, separate sessions for spike work, council debates). Plain Ghostty handles this with tab-per-session, but every session is visually equal — no sidebar listing which workspace is active, no per-workspace branch/PR visibility, no notification when an unfocused session completes a tool call. Managing N parallel Claude sessions in a stock terminal is mechanical and error-prone.

cmux (manaflow-ai/cmux) is a libghostty-based AI-pane manager built specifically for this workload: workspace-per-Claude-session sidebar, per-workspace branch + PR + ports + logs, notification hooks tied to Claude Code lifecycle. Built on the same libghostty Ghostty exposes (see [ARCH-0010](ARCH-0010 Primary terminal emulator Ghostty.md)).

The question: replace Ghostty with cmux, or coexist?

## Decision Drivers

- Daily-driver workflow IS multi-Claude — the agent-first ergonomics outweigh "general-purpose terminal" use cases
- Notification ergonomics for backgrounded Claude sessions matter more than chrome aesthetics
- Quick-terminal drop-down (`cmd+§`) is a load-bearing macOS habit; cmux explicitly lacks it ([cmux#2758](https://github.com/manaflow-ai/cmux/issues/2758))
- Both apps share libghostty fundamentals — config knobs for appearance/keys carry across
- cmux ships rapidly (weekly+ releases); update cadence has to be controlled (see [ARCH-0014](ARCH-0014 Brewfile vs manual DMG criteria.md))

## Considered Options

1. **Replace Ghostty with cmux fully.** Loses the quick-terminal drop-down; would need another solution (BetterDummy-style overlay, third app like iTerm2's hotkey window).
2. **Keep Ghostty, ignore cmux.** Loses the multi-Claude ergonomics; managing parallel sessions remains mechanical.
3. **cmux primary for agent workflows, Ghostty secondary for quick-terminal.** Both apps installed, both used. No conflict (cmux's `cmd+§` binding doesn't fire; Ghostty's global binding still does).

## Decision Outcome

Chosen option: **cmux primary for agent workflows, Ghostty secondary for quick-terminal**.

cmux opens at login, hosts all multi-Claude work (workspace per session, sidebar with branch + PR + ports, notification rings, dock badge, pane flash). Ghostty stays installed for `cmd+§` quick-terminal drop-down only — used for one-off shell commands without disturbing the cmux workspace layout.

Both share `~/.config/ghostty/config` for the appearance/key-reporting subset (font, theme, kitty protocol, OSC 52). cmux's app-specific config lives at `~/.config/cmux/cmux.json` (sidebar style, indicator style, notification hooks, workspace colors). Reload binding rebound from cmux's default `cmd+shift+,` to `cmd+shift+r` for Ghostty muscle memory.

cmux is installed via `scripts/install/cmux.sh` (manual DMG, not Brewfile cask) because cmux's release cadence makes unattended `brew upgrade` unsafe — see [ARCH-0014](ARCH-0014 Brewfile vs manual DMG criteria.md) for the criteria.

After install, the one-time setup is `cmux hooks setup` — wires Claude Code lifecycle hooks into `~/.claude/settings.json` so cmux receives PreToolUse/PostToolUse/Stop events from every Claude session.

### Consequences

- [+] Multi-Claude workflows have proper ergonomics — workspace sidebar, per-workspace status, notification rings
- [+] libghostty config (appearance, kitty protocol) reused between Ghostty and cmux
- [+] Ghostty's `cmd+§` quick-terminal stays available for one-off use
- [+] No conflict between the two apps — cmux ignores Ghostty's global binding harmlessly
- [-] Two apps to keep aligned on libghostty version bumps
- [-] cmux update cadence requires manual DMG flow (no `brew upgrade`)
- [-] `cmux hooks setup` is a manual one-time step the install script can't automate
- [-] Notifications + paneFlash for AI sessions can be loud during heavy review work; tune via cmux.json

## More Information

- [scripts/install/cmux.sh](../../scripts/install/cmux.sh) — DMG installer
- [`dotfiles/dot_config/cmux/cmux.json`](https://github.com/N4M3Z/dotfiles/blob/main/dot_config/cmux/cmux.json) — cmux app config
- [cmux config schema](https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json)
- [cmux documentation](https://cmux.com/docs/configuration)
- [cmux notifications docs](https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md)
