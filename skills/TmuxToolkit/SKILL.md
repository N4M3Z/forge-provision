---
name: TmuxToolkit
version: 0.1.0
description: "Tmux setup as a toolkit of best-practice config, plugins, and gotchas-with-fixes. Covers baseline config (true color, kitty protocol pass-through, OSC 52 clipboard, focus events, mouse), plugin management via chezmoi externals, TPM bootstrap, tmux-resurrect + tmux-continuum for session persistence, catppuccin theming. USE WHEN configuring tmux, adopting tmux plugins, fixing kitty-protocol passthrough into helix or neovim, restoring sessions across reboots, debugging tmux behavior under Ghostty or cmux, or tuning the status line."
sources:
    - https://github.com/tmux/tmux/wiki
    - https://github.com/tmux-plugins/tpm
    - https://github.com/tmux-plugins/tmux-resurrect
    - https://github.com/tmux-plugins/tmux-continuum
    - https://github.com/catppuccin/tmux
    - https://www.chezmoi.io/reference/special-files-and-directories/chezmoiexternal-format/
    - https://sw.kovidgoyal.net/kitty/keyboard-protocol/
    - https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands
---

# TmuxToolkit

Best-practice tmux configuration for the persistent-session layer beneath Ghostty / cmux. Concrete config, plugins worth shipping, and the kitty-protocol + OSC 52 + truecolor plumbing that lets modern TUIs work cleanly inside a multiplexed session.

For invocation, keybindings, and save/quit semantics see `docs/tldrs/tmux.md`.

## Baseline config

Drop these into the chezmoi source at `dot_config/tmux/tmux.conf` (deploys to `~/.config/tmux/tmux.conf`):

```tmux
# True color + tmux-256color terminfo
set -g default-terminal "tmux-256color"
set -as terminal-overrides ",*-256color:Tc"

# Kitty keyboard protocol — accept extended sequences from the outer terminal
# and advertise extended-keys support to the inner TUI.
set -g extended-keys on
set -as terminal-features 'xterm*:extkeys'

# OSC 52 clipboard — copy in tmux propagates to the macOS clipboard.
set -g set-clipboard on

# Focus events — inner editors auto-reload when files change outside.
set -g focus-events on

# Mouse on — drag-resize, click-to-focus, scroll.
set -g mouse on

# No vim escape lag.
set -g escape-time 10

# Large scrollback per pane.
set -g history-limit 100000

# 1-indexed windows + panes, contiguous renumber on close.
set -g base-index 1
set -g pane-base-index 1
set -g renumber-windows on
```

The `Tc` capability + `terminal-features 'xterm*:extkeys'` pair is the canonical incantation; both halves are needed (the outer→tmux hop *and* the tmux→inner hop) for modifier-rich keystrokes to survive.

## Plugin management via chezmoi externals

TPM's `prefix + I` to install plugins is imperative — a fresh Mac would have no plugins until you press the key. chezmoi externals make plugin clones declarative:

```toml
# dotfiles/.chezmoiexternal.toml
[".config/tmux/plugins/tpm"]
    type = "git-repo"
    url = "https://github.com/tmux-plugins/tpm.git"
    refreshPeriod = "168h"

[".config/tmux/plugins/tmux-resurrect"]
    type = "git-repo"
    url = "https://github.com/tmux-plugins/tmux-resurrect.git"
    refreshPeriod = "168h"

[".config/tmux/plugins/tmux-continuum"]
    type = "git-repo"
    url = "https://github.com/tmux-plugins/tmux-continuum.git"
    refreshPeriod = "168h"

[".config/tmux/plugins/catppuccin-tmux"]
    type = "git-repo"
    url = "https://github.com/catppuccin/tmux.git"
    refreshPeriod = "168h"
```

`chezmoi apply` clones each repo at first run and refreshes weekly. TPM still parses the `@plugin` lines in `tmux.conf` to register and load each plugin — only the clone step is taken out of TPM's hands. Pin a plugin by setting `refreshPeriod = "8760h"` (one year) until you bump it.

Append TPM bootstrap to the *end* of `tmux.conf`:

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'catppuccin/tmux'

run '~/.config/tmux/plugins/tpm/tpm'
```

The `run` line must be last; TPM reads the `@plugin` declarations above it and sources each plugin's entry script.

## Session persistence

`tmux-resurrect` + `tmux-continuum` is the persistent-session pair:

```tmux
# tmux-resurrect — save / restore the session graph
set -g @resurrect-strategy-vim 'session'
set -g @resurrect-strategy-nvim 'session'
set -g @resurrect-processes 'ssh helix nvim "git log" "git diff"'

# tmux-continuum — auto-save every 15 min, auto-restore on server start
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
```

Resurrect captures sessions, windows, panes, pane CWDs, and pane processes from `@resurrect-processes`. vim/nvim/helix are first-class via the `-strategy-*` knobs; ad-hoc REPLs come back as bare shells unless added to the processes list. `prefix+Ctrl-s` saves now, `prefix+Ctrl-r` restores last save.

Snapshots land under `~/.local/share/tmux/resurrect/`. Audit growth periodically — resurrect keeps every snapshot.

## Catppuccin theming

```tmux
set -g @catppuccin_flavor 'mocha'                    # latte | frappe | macchiato | mocha
set -g @catppuccin_window_status_style 'rounded'     # basic | rounded | slanted | custom | none

# Module-driven status-right composition.
set -g @catppuccin_status_modules_right 'application session date_time'
```

The `@plugin 'catppuccin/tmux'` line MUST come before any `@catppuccin_*` option that references module files; the include logic resolves only after the plugin is sourced. Wrong order → status-line modules render as raw `#{...}` strings.

## Kitty keyboard protocol — three sides have to agree

| Layer            | What it needs                                                                          |
| ---------------- | -------------------------------------------------------------------------------------- |
| Ghostty (outer)  | kitty-protocol on (default in recent versions); `macos-option-as-alt` consistent.       |
| tmux (middle)    | `extended-keys on` + `terminal-features 'xterm*:extkeys'` (in the baseline above).      |
| helix / nvim (inner) | `keyboard-protocol = "kitty"` (helix) or the equivalent `:set` lines (neovim).     |

When all three agree, Alt+Arrow, Shift+Tab, Ctrl+Tab survive into the inner editor with the correct modifier flags. When one disagrees, modifier-rich keystrokes get downgraded silently.

## OSC 52 clipboard

`set-clipboard on` enables tmux to honor OSC 52 escapes — copies inside tmux propagate to the macOS clipboard without `pbcopy`. The terminal also has to permit OSC 52 writes; Ghostty defaults are sane.

For copy-mode vi keys with a belt-and-braces `pbcopy` fallback:

```tmux
set -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
```

The explicit `pbcopy` pipe rescues clients that don't honor OSC 52 (legacy iTerm2 profiles, some headless setups).

## Common pitfalls

| Symptom                                                              | Cause / Fix                                                                                                                |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Cmd+click on a URL inside tmux does nothing                          | tmux's `mouse on` captures the click. Use `Cmd+Shift+click` to bypass tmux mouse capture and hand the click to Ghostty.    |
| Alt+Arrow does nothing inside tmux+Ghostty                            | `extended-keys on` + `terminal-features 'xterm*:extkeys'` missing, or `macos-option-as-alt` and extkeys disagree.          |
| Resurrect restore leaves processes as bare shells                     | Process not in `@resurrect-processes`. Add it, save, retry restore.                                                        |
| Plugins don't load after `chezmoi apply` cloned them                  | TPM only loads at server start. `tmux kill-server && tmux`, or source the TPM `run` line manually.                          |
| Status-line modules render as raw `#{...}` strings                   | `@plugin 'catppuccin/tmux'` is below the `@catppuccin_status_modules_right` line. Move the @plugin line above it.          |
| `default-terminal` warning at start                                   | `tmux-256color` terminfo missing. `infocmp tmux-256color` to verify; on stale macOS, fetch from ncurses git.               |
| Vim-style hjkl pane navigation jumps inside an inner editor           | Use `vim-tmux-navigator` plugin or guard `bind-key h select-pane -L` with `if-shell` that checks the active program.       |
| `prefix+I` does nothing                                               | TPM not bootstrapped at the end of tmux.conf. The `run '~/.config/tmux/plugins/tpm/tpm'` line must be the last line.       |

## Reload after edit

```sh
tmux source-file ~/.config/tmux/tmux.conf      # reload running server, preserve sessions
```

Don't restart the tmux server unless changing init-only settings (`default-terminal`, terminfo) — `kill-server` drops every session that isn't restored by continuum on next start.
