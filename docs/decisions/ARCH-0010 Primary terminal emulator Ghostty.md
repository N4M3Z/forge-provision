---
title: Primary terminal emulator — Ghostty
description: Ghostty is the daily-driver terminal emulator. Native macOS (Zig + Swift), GPU-accelerated, kitty-protocol-native, libghostty as a stable reusable library, MIT-licensed. Apple Terminal kept as ssh-managed fallback.
type: adr
category: tooling
tags:
    - terminal
    - emulator
    - ghostty
    - libghostty
    - macos
status: accepted
created: 2026-05-21
updated: 2026-05-21
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0009 Terminal multiplexer tmux.md"
    - "ARCH-0011 cmux as agent overlay on libghostty.md"
    - "ARCH-0012 libghostty as strategic substrate.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Primary terminal emulator — Ghostty

## Context and Problem Statement

A terminal emulator is the host process for shells, TUIs, and multiplexers. Selection drives performance (GPU vs CPU rendering), feature surface (kitty keyboard protocol, ligatures, image protocols), customization model (config file, plugin system, scriptable), macOS-native feel (titlebar, fullscreen, quick-terminal), and long-term ecosystem trajectory.

The new Mac (Mac17,6, macOS Tahoe 26) inherits no prior terminal choice. Picking the daily driver shapes the entire terminal-stack ecosystem decisions (multiplexer, AI overlays like cmux, theme portability).

## Decision Drivers

- Native macOS feel (titlebar style, fullscreen behavior, quick-terminal, blur/vibrancy)
- GPU-accelerated rendering for low input latency at high font sizes
- Kitty keyboard protocol support for unambiguous modifier reporting into inner TUIs
- Sane defaults — minimal config to reach "looks and feels right"
- Stable reusable substrate so future apps (cmux, IDEs, agent terminals) can build on it
- Permissive license, healthy maintainer model

## Considered Options

1. **Apple Terminal.app.** Default baseline. Minimal customization, AppleScript bridge, no GPU acceleration, no kitty protocol. Stays installed as fallback.
2. **iTerm2.** Saturated feature surface, Objective-C, plugin-via-features model. Mature, very customizable. CPU-rendered (Metal exists but not the default); subjective input lag at high fonts. License is GPL-2.
3. **Alacritty.** Rust, GPU-accelerated, minimal feature surface. No tabs, no scrollback search beyond `vi mode` — pairs with a multiplexer mandatorily. MIT.
4. **kitty.** GPU + the kitty-protocol authors. Native ligatures, image protocol, sessions. Python config DSL is divisive. GPL-3.
5. **WezTerm.** Rust, Lua config, multiplexer built in. Rich feature surface; some users find the Lua config heavyweight. MIT.
6. **Ghostty.** Zig + Swift, GPU-accelerated, native macOS chrome, kitty-protocol native, MIT. libghostty as a stable reusable terminal library. Backed by Mitchell Hashimoto's long-term maintenance plan.

## Decision Outcome

Chosen option: **Ghostty as the primary terminal emulator on macOS**.

Ghostty wins on:
- **Native macOS chrome.** `macos-titlebar-style = transparent`, notch-aware fullscreen (`padded-notch`), native window-blur/vibrancy via `background-blur`, native quick-terminal drop-down.
- **GPU-accelerated rendering** with `display-p3` colorspace on Apple Silicon Retina — palpably lower latency than iTerm2 at 15pt+.
- **Kitty keyboard protocol** native — modifier-rich keystrokes (Alt+Arrow, Shift+Tab, Ctrl+Tab) reach inner TUIs unambiguously when tmux and the inner editor agree (see [ARCH-0014](ARCH-0014 Kitty keyboard protocol adoption.md)).
- **Sane defaults.** `notify-on-command-finish=unfocused`, OSC 52 clipboard, `shell-integration` features for ssh-terminfo / ssh-env, no plugin system to maintain.
- **libghostty as a library.** Stable C ABI, reused by cmux (see [ARCH-0011](ARCH-0011 cmux as agent overlay on libghostty.md)). Choosing Ghostty also chooses libghostty as a strategic substrate (see [ARCH-0012](ARCH-0012 libghostty as strategic substrate.md)).
- **MIT license, single maintainer with a long-term plan.** Lower bus-factor risk than community-driven projects with diffuse governance.

iTerm2 and Apple Terminal remain installable (both are part of macOS or trivially restored), but Ghostty is the daily driver and the canonical reference for config in `dotfiles/dot_config/ghostty/config`.

For Ghostty configuration, kitty protocol setup, macOS-native integration, and the three known Ghostty+tmux trap zones, see [GhosttyToolkit](../../skills/GhosttyToolkit/SKILL.md).

### Consequences

- [+] One stable terminal config, portable across machines via chezmoi
- [+] libghostty as a substrate for cmux + any future libghostty-based apps
- [+] Kitty protocol native — fewer modifier-reporting bugs across the inner TUI stack
- [+] macOS-native feel without an Objective-C extension surface to maintain
- [-] Single-maintainer dependency — bus factor higher than community-led projects
- [-] No plugin system — extensions limited to themes, shaders, includes, keybind chords
- [-] Apple Silicon performance is the optimization target; Intel paths exist but receive less attention
- [-] Ghostty 1.x is recent; config knobs still evolving across point releases (test config after upgrades)

## More Information

- [GhosttyToolkit skill](../../skills/GhosttyToolkit/SKILL.md) — config best practices and tmux interop
- [Ghostty config reference](https://ghostty.org/docs/config/reference)
- [ARCH-0013 Terminal landscape Wave and Warp evaluated](ARCH-0013 Terminal landscape Wave and Warp evaluated.md) — the broader survey of contenders
- [ARCH-0012 libghostty as strategic substrate](ARCH-0012 libghostty as strategic substrate.md) — the implication of picking Ghostty
