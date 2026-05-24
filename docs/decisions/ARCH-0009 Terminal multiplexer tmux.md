---
title: Terminal multiplexer — tmux as the persistent session layer
description: tmux owns persistent sessions, panes, and resurrect/continuum across reboots. Native emulator splits (Ghostty, cmux) handle window chrome; tmux handles persistence and SSH-host reattach.
type: adr
category: tooling
tags:
    - terminal
    - tmux
    - multiplexer
    - persistence
    - session
status: accepted
created: 2026-05-21
updated: 2026-05-21
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

# Terminal multiplexer — tmux as the persistent session layer

## Context and Problem Statement

Terminal sessions on a developer machine outlive single terminal windows. Sleep / wake, app crashes, OS updates, occasional `kill -9` — any of these tears down emulator state, taking pane layouts, REPL processes, and inflight work with them. SSH connections from another host need a way to attach, detach, and reattach without losing context. Native emulator splits (Ghostty 1.x, cmux) own window chrome and visual layout but evaporate with the emulator process; they have no persistent-session graph.

The question: what owns the persistent layer underneath the emulator?

## Decision Drivers

- Sessions must survive emulator close, OS sleep, and app crash
- A pane's CWD and active process should restore on resurrection, not just an empty shell
- SSH-host workflows need attach/detach/reattach without ceremony
- The multiplexer's keymap must not collide with emulator chrome or inner-TUI keybinds destructively
- Cross-emulator portability — switching from Ghostty to cmux to plain Apple Terminal must not lose the session graph

## Considered Options

1. **No multiplexer — rely on emulator-native splits only.** Lightest setup. Fails the persistence requirement entirely.
2. **tmux as the persistent layer.** Battle-tested (20+ years), broadest plugin ecosystem, resurrect + continuum solve the persistence-with-state-restore problem.
3. **zellij.** Rust, layout-first, better defaults, attractive theming. Weaker plugin ecosystem; no resurrect equivalent at parity. Worth re-evaluating yearly.
4. **screen.** Universal baseline, on every box. Sparse modernization; resurrect-style snapshots require external tooling.
5. **Emulator-native + dtach / abduco for persistence only.** Two tools to wire; loses the multiplexer's keymap consistency across hosts.

## Decision Outcome

Chosen option: **tmux as the persistent layer beneath any emulator**.

Native emulator splits (Ghostty `cmd+d` / `cmd+shift+d`, cmux panes) keep window chrome. tmux underneath owns the persistent session graph via `tmux-resurrect` + `tmux-continuum`: snapshot every 15 min, auto-restore on tmux server start, manual save/restore via `prefix+Ctrl-s` / `prefix+Ctrl-r`.

Plugin management uses chezmoi externals rather than TPM's imperative `prefix+I` — see [ARCH-0005](ARCH-0005 Dotfiles engine chezmoi.md) for the externals decision. This makes a fresh Mac's tmux setup deterministic from `chezmoi apply` alone.

The setup carries across emulators: switching from Ghostty to cmux to Apple Terminal leaves the tmux server (and its sessions) untouched. SSH hosts get the same tmux setup deployed via chezmoi; sessions can be detached locally and reattached remotely, or vice versa.

For tmux configuration, plugin selection, kitty-protocol pass-through, and OSC 52 clipboard setup, see [TmuxToolkit](../../skills/TmuxToolkit/SKILL.md).

### Consequences

- [+] Sessions persist across emulator restart, sleep/wake, server reboot
- [+] Resurrect captures CWD + known process types; restoration is meaningful, not just empty shells
- [+] Cross-emulator portability — the multiplexer's keymap is the constant across Ghostty / cmux / Terminal.app / SSH-host emulators
- [+] Plugin set is declarative via chezmoi externals
- [-] Two layers of pane management (tmux + emulator splits) — slight cognitive overhead per session
- [-] Kitty keyboard protocol requires three-way agreement (emulator + tmux + inner editor); see [ARCH-0014](ARCH-0014 Kitty keyboard protocol adoption.md)
- [-] Resurrect can't restore arbitrary unknown processes — only those in `@resurrect-processes`

## More Information

- [TmuxToolkit skill](../../skills/TmuxToolkit/SKILL.md) — config best practices, plugin setup
- [docs/tldrs/tmux.md](../tldrs/tmux.md) — invocation and keybinding reference
- [tmux wiki](https://github.com/tmux/tmux/wiki)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
- [tmux-plugins/tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)
