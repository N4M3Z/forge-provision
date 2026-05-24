---
title: Kitty keyboard protocol adoption
description: The kitty keyboard protocol is enabled across the terminal stack (Ghostty + tmux + inner TUIs) for unambiguous modifier reporting. Three-way agreement required; default-on where possible.
type: adr
category: tooling
tags:
    - terminal
    - keyboard
    - kitty-protocol
    - tmux
    - ghostty
status: accepted
created: 2026-05-21
updated: 2026-05-21
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0009 Terminal multiplexer tmux.md"
    - "ARCH-0010 Primary terminal emulator Ghostty.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Kitty keyboard protocol adoption

## Context and Problem Statement

The xterm keyboard reporting format (`CSI 27 ; <mod> ; <key> ~`) is ambiguous and lossy. Many modifier+key combinations collapse to the same byte sequence as the bare key — Ctrl+i and Tab both emit `^I`, Ctrl+m and Enter both emit `^M`, Shift+Tab disambiguation depends on extended-mode toggles, Alt+Arrow rides on macos-option-as-alt setups that don't always agree across the stack.

The [kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) replaces this with explicit modifier bitmasks (`CSI <key> ; <mod> u`), making every modifier+key combination uniquely reportable. Modern TUIs (helix, neovim, gitui) opt in to gain unambiguous bindings — Ctrl+Tab for window-cycle, Alt+H/J/K/L for pane focus, Shift+Enter for multi-line input, etc.

The protocol only works when **every layer agrees** — outer terminal emits the extended sequences, multiplexer passes them through, inner TUI consumes them. One disagreement and modifier-rich keystrokes downgrade silently to bare keys, breaking bindings without surfacing an error.

## Decision Drivers

- Inner-editor bindings (helix multi-cursor, neovim modifier-rich operators) are load-bearing on modifier reporting
- Three-way agreement is brittle — version drift in any layer breaks everything below it
- The downgrade is silent; debugging requires tracing each layer's protocol state
- Some legacy TUIs (older ncurses-based, certain SSH-hosted TUIs) misinterpret the extended sequences

## Considered Options

1. **Don't adopt kitty protocol.** Stay on xterm sequences. Modifier-rich bindings collapse to whatever xterm can express; lose helix/neovim's modern bindings.
2. **Adopt kitty protocol across the full stack.** Three-way agreement (Ghostty + tmux + inner TUI), every layer opted in. Best inner-editor experience; brittle on version drift.
3. **Per-tool opt-in (some layers opt in, some don't).** Inconsistent; the agreement chain is intentional — half-adoption is worse than full or none.

## Decision Outcome

Chosen option: **adopt kitty protocol across the full stack**.

### The three-way agreement

| Layer            | Setting                                                                          |
| ---------------- | -------------------------------------------------------------------------------- |
| Ghostty (outer)  | kitty-protocol on by default in 1.x. `macos-option-as-alt = left` for consistency. |
| tmux (middle)    | `set -g extended-keys on` + `set -as terminal-features 'xterm*:extkeys'` in `tmux.conf` |
| Inner editor     | helix `[editor] true-color = true` + `keyboard-protocol = "kitty"`; neovim equivalent `:set` lines |

All three are set in the chezmoi-managed configs: `dot_config/ghostty/config`, `dot_config/tmux/tmux.conf`, `dot_config/helix/config.toml`. A fresh Mac running `chezmoi apply` lands the agreement chain ready to use.

### Known failure modes (from session experience)

- **`macos-option-as-alt` ↔ `extkeys` mismatch (Ghostty 1.2.3+).** tmux emits xterm format `ESC[27;2;13~` while kitty-protocol-aware apps expect `ESC[13;2u`. Fix on the tmux side: `set -s extended-keys always` (xterm format everywhere) or drop `extkeys` from `terminal-features` (accept the capability loss). Source: [Ghostty discussion #9340](https://github.com/ghostty-org/ghostty/discussions/9340).
- **Alt+Arrow word-jump regression** inside tmux with `extended-keys on` + `extkeys` terminal-feature. Symptom: Option+Left in nvim inside tmux beeps or inserts garbage. Fix: unbind Ghostty's Alt+Arrow handlers (`keybind = alt+left=unbind` etc.) so the keys forward cleanly. Source: [Ghostty discussion #2845](https://github.com/ghostty-org/ghostty/discussions/2845).
- **Legacy TUIs misinterpret extended sequences.** Rare; mitigation is opt-out per-tool inside that TUI's config rather than disabling protocol layer-wide.

See [GhosttyToolkit](../../skills/GhosttyToolkit/SKILL.md) and [TmuxToolkit](../../skills/TmuxToolkit/SKILL.md) for the config-level details and pitfall tables.

### Consequences

- [+] Modern modifier-rich bindings work as documented in helix, neovim, gitui
- [+] One config story across the stack — three places to touch, consistent surface
- [+] Inner-TUI bindings (Shift+Tab, Ctrl+Tab, Alt+Arrow) are unambiguous
- [-] Three-way agreement is brittle — Ghostty version bump can introduce the kind of ESC[...] format mismatch the discussions above catalog
- [-] Diagnostic effort when a binding "stops working" — verify each layer's protocol state, not just the symptom layer
- [-] Some legacy TUIs need per-tool opt-out; one more thing to know

## More Information

- [Kitty keyboard protocol spec](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
- [GhosttyToolkit skill](../../skills/GhosttyToolkit/SKILL.md) — Ghostty-side settings + the three known trap zones
- [TmuxToolkit skill](../../skills/TmuxToolkit/SKILL.md) — tmux-side pass-through and the agreement table
- [Ghostty discussion #9340](https://github.com/ghostty-org/ghostty/discussions/9340) — macos-option-as-alt + extkeys mismatch
- [Ghostty discussion #2845](https://github.com/ghostty-org/ghostty/discussions/2845) — Alt+arrow regression under tmux
- [Ghostty discussion #8756](https://github.com/ghostty-org/ghostty/discussions/8756) — Cmd+1-9 tmux vs Ghostty tabs routing
