---
title: macOS Terminal profile
description: Terminal profile lives in dotfiles, env-configurable; applied via plist write + AppleScript bridge so a running Terminal picks it up immediately
type: adr
category: tooling
tags:
    - terminal
    - profile
    - macos
    - dotfiles
    - applescript
status: accepted
created: 2026-05-11
updated: 2026-05-11
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

# macOS Terminal profile

## Context and Problem Statement

A fresh macOS Terminal.app needs a configured profile (colors, font, cursor, selection). `.terminal` files are XML plists Terminal.app imports natively. Two concerns to settle:

1. **Where the profile file lives.** Per-user config — a standalone "themes" repo is overkill for one file per emulator.
2. **How to apply it as the default.** `defaults write com.apple.terminal "Default Window Settings"` updates the plist, but a *running* Terminal.app caches default-settings at launch and ignores the plist change — and can write its own state back on quit, overwriting the value. The symptom: "I imported the new profile, but it's not the default for new windows."

The plist-vs-running gap is not Terminal-specific; the same pattern recurs whenever a macOS app caches "default template" state at launch.

## Decision Drivers

- The profile file is per-user config — it lives where other per-user config lives
- Install script is env-configurable: which file, where to find it
- Idempotent application — re-running with the same target is a clean no-op
- No user-visible "restart Terminal for this to apply"
- No `pkill -x Terminal` — would kill the session running the script
- Works whether Terminal is running or not

## Considered Options

**For where the file lives:**

1. **Dedicated user-owned `themes` repo** — separation of concerns, overkill for a per-user file
2. **Profile file in dotfiles** (chezmoi-managed) — single place for per-user config; chezmoi lays it down at apply-time
3. **In `forge-provision` itself** — wrong scope; provisioning scripts use the file, they don't own it

**For where the upstream `.terminal` comes from** (when not authoring own):

1. **`Gogh-Co/Gogh`** — 360+ themes; no Homebrew formula; iTerm-only on macOS
2. **`mbadolato/iTerm2-Color-Schemes`** — 450+ profiles in `terminal/`; cross-emulator subdirs
3. **`themer.dev`** — palette generator; useful once a custom palette exists
4. **`tinted-theming` / base16** — cross-emulator successor to chriskempson/base16
5. **`catppuccin`** — per-emulator install repos; no Terminal.app coverage in main repo

**For application mechanism:**

1. **Plist-write only + ask user to relaunch Terminal** — not idempotent in the strict sense
2. **`pkill -x Terminal` after plist write** — kills the running session — unacceptable
3. **AppleScript only** — works for running Terminal; silently launches Terminal if not running; doesn't persist if Terminal writes plist back on quit
4. **Plist + AppleScript via System Events** — write the plist (for next launch) AND drive AppleScript only if Terminal is already running

## Decision Outcome

**Where the file lives**: profile file in dotfiles (`chezmoi`-managed). `scripts/install/terminal-theme.sh` reads `TERMINAL_PROFILE` (file name without extension) and `TERMINAL_PROFILE_DIR` (directory containing `<name>.terminal`) from `.env`. Default points at the dotfiles-laid path; users can override to mbadolato (auto-cloned) or any other compatible source without modifying the script. A separate `themes` repo is **not** created.

**Application mechanism**: plist + AppleScript via System Events. The script writes `Default Window Settings` and `Startup Window Settings` via `defaults write`, then issues AppleScript wrapped in `tell application "System Events"` — which checks `(name of processes) contains "Terminal"` before issuing the inner `tell application "Terminal"`. If Terminal isn't running, only the plist write happens; next launch picks it up. If Terminal IS running, in-memory state syncs immediately.

Idempotency check reads both sources: skip only if plist matches AND (Terminal not running OR Terminal's view matches). The same plist + System-Events-guarded AppleScript pattern generalizes to other "default template" provisioning on macOS — Finder window defaults, Mail signatures, Stickies templates — and is the canonical shape for those scripts.

### Consequences

- [+] One repo (dotfiles) owns per-user config, including the Terminal profile
- [+] chezmoi handles placement; install script handles import + default-set
- [+] Env-configurable source means upstream profiles can be swapped in
- [+] Idempotent — re-running with the same target is a no-op
- [+] No process killing; active session is safe
- [+] Pattern generalizes to other macOS default-template provisioning
- [-] Coupling to chezmoi migration: until that lands, the profile file is hand-placed or held in an interim location
- [-] First run may prompt for Automation permission via macOS TCC — one-time UX cost
- [-] AppleScript-in-bash is always slightly awkward

## More Information

- [mbadolato/iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) — default upstream source
- [Gogh-Co/Gogh](https://github.com/Gogh-Co/Gogh) — rejected (iTerm-only on macOS)
- [themer.dev](https://themer.dev) — future palette generator
- Apple Developer — `tell application "Terminal"` and `tell application "System Events"` AppleScript references
