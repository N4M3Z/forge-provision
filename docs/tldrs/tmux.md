# tmux

Terminal multiplexer. Persistent sessions, windows, panes that survive terminal close and SSH disconnect. **Prefix is `Ctrl+b`** (default; not overridden in our config).

## Invocation

| Command | Effect |
|---|---|
| `tmux` | New session (auto-named `0`, `1`, ...) |
| `tmux new -s <name>` | New named session |
| `tmux ls` | List running sessions |
| `tmux a` / `tmux attach` | Attach to most recent session |
| `tmux a -t <name>` | Attach to named session |
| `tmux kill-session -t <name>` | Kill one session |
| `tmux kill-server` | Kill everything (last resort) |
| `tmux source-file ~/.config/tmux/tmux.conf` | Reload config without killing server |

## Custom keybindings (in our `dot_config/tmux/tmux.conf`)

Read these as: hold `Ctrl`, tap `b`, release `Ctrl`, then tap the next key (with any noted modifier).

### Panes

| Key | Action |
|---|---|
| `prefix + h` / `j` / `k` / `l` | Vim-style pane focus (left / down / up / right) |
| `Alt + h` / `j` / `k` / `l` | Same, no prefix needed (one-keystroke pane jump) |
| `prefix + |` | Split horizontally (new pane to the right), inherits cwd |
| `prefix + -` | Split vertically (new pane below), inherits cwd |
| `prefix + z` | Zoom current pane to fullscreen / unzoom |
| `prefix + x` | Kill current pane |
| `prefix + space` | Cycle through preset layouts |

### Windows (tabs)

| Key | Action |
|---|---|
| `prefix + c` | New window |
| `prefix + 1`-`9` | Jump to window N |
| `prefix + n` / `p` | Next / prev window |
| `prefix + w` | Window picker |
| `prefix + ,` | Rename current window |
| `prefix + &` | Kill current window |

### Sessions

| Key | Action |
|---|---|
| `prefix + s` | Session picker |
| `prefix + $` | Rename current session |
| `prefix + d` | Detach from session (it keeps running) |

### Plugin commands (resurrect + continuum)

| Key | Action |
|---|---|
| `prefix + Ctrl-s` | Save tmux state now (resurrect manual save) |
| `prefix + Ctrl-r` | Restore last saved state |
| (automatic) | continuum auto-saves every 15 min; auto-restores on tmux server start |

**Use these before quitting Ghostty.** Resurrect captures: sessions, windows, panes, pane CWDs, and pane processes it knows how to revive (vim/nvim/helix yes, transient TUIs may not). Continuum's auto-restore picks up the last save when tmux starts fresh.

### Copy mode (vi keys)

| Key | Action |
|---|---|
| `prefix + [` | Enter copy mode |
| `q` / `Esc` | Exit copy mode |
| `j` / `k` / `h` / `l` | Move cursor |
| `gg` / `G` | Top / bottom |
| `/` / `?` | Search forward / back |
| `n` / `N` | Next / prev search match |
| `Ctrl+u` / `Ctrl+d` | Page up / down |

(Note: our config has `mode-keys vi` live but no explicit `v` / `y` bindings. To extend, add `bind-key -T copy-mode-vi v send-keys -X begin-selection` and `bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"` to tmux.conf.)

## Plugins via chezmoi external

Cloned by `chezmoi apply`, not by TPM's `prefix + I`. Source of truth is `dotfiles/.chezmoiexternal.toml`:

| Plugin | Path | Purpose |
|---|---|---|
| `tmux-plugins/tpm` | `~/.config/tmux/plugins/tpm` | Runner that sources plugins listed as `@plugin` in tmux.conf |
| `tmux-plugins/tmux-resurrect` | `~/.config/tmux/plugins/tmux-resurrect` | Save/restore tmux state |
| `tmux-plugins/tmux-continuum` | `~/.config/tmux/plugins/tmux-continuum` | Auto-save + auto-restore on start |

To add a plugin: append a `[".config/tmux/plugins/<name>"]` block to `.chezmoiexternal.toml`, add `set -g @plugin '<owner>/<name>'` to tmux.conf, run `chezmoi apply`, reload tmux config (`tmux source-file ~/.config/tmux/tmux.conf`).

## Notable config baked in

- `default-terminal = "tmux-256color"`, `terminal-features` advertises RGB / clipboard / focus / extkeys to make kitty keyboard protocol survive
- `set-clipboard on` — OSC52 propagates inside-tmux copies to the macOS clipboard
- `focus-events on` — nvim/helix auto-reload on file change works
- `mouse on` — drag-resize, click-to-focus, scroll
- `escape-time 10` — no vim escape lag
- `history-limit 100000` — large scrollback per pane
- `base-index 1`, `pane-base-index 1`, `renumber-windows on` — 1-indexed, contiguous renumber on close

## URL clicks inside tmux (Ghostty)

`Cmd+click` doesn't open URLs when tmux has `mouse on` (tmux eats the click). Use **`Cmd+Shift+click`** instead — Shift bypasses tmux mouse capture and gives the click back to Ghostty. See [docs/tldrs/ghostty.md] (if/when written) for the rationale.

## Config + reload

- Canonical: `~/Developer/N4M3Z/dotfiles/dot_config/tmux/tmux.conf`
- Deployed: `~/.config/tmux/tmux.conf`
- Deploy: `chezmoi apply ~/.config/tmux/tmux.conf`
- Reload running server (preserves all sessions): `tmux source-file ~/.config/tmux/tmux.conf`

## Sources

- [tmux wiki](https://github.com/tmux/tmux/wiki)
- [tmux-plugins/tpm](https://github.com/tmux-plugins/tpm)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
- [tmux-plugins/tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)
- [chezmoi external format](https://www.chezmoi.io/reference/special-files-and-directories/chezmoiexternal-format/)
