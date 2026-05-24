---
name: GhosttyToolkit
version: 0.1.0
description: "Ghostty configuration best practices: appearance + window chrome, macOS-native integration (quick terminal, option-as-alt, titlebar style), kitty keyboard protocol, OSC 8 hyperlink hover, shell integration features, multi-line input for Claude Code, the three known Ghostty+tmux trap zones. USE WHEN configuring Ghostty, debugging key reporting under tmux, wiring the macOS quick terminal, restoring sessions across relaunch, tuning URL hover cost, or aligning option-as-alt and extkeys."
sources:
    - https://ghostty.org/docs/config/reference
    - https://ghostty.org/docs/config
    - https://sw.kovidgoyal.net/kitty/keyboard-protocol/
    - https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands
    - https://github.com/ghostty-org/ghostty/discussions/8756
    - https://github.com/ghostty-org/ghostty/discussions/2845
    - https://github.com/ghostty-org/ghostty/discussions/9340
---

# GhosttyToolkit

Best-practice Ghostty configuration. macOS-native, GPU-accelerated, kitty-protocol-native; libghostty is the substrate cmux is built on, so settings carry across both apps for the appearance/key-reporting subset.

Config lives at `~/.config/ghostty/config` (canonical source: `dot_config/ghostty/config` under chezmoi). Reload binding: `cmd+shift+r` (overridden from default `cmd+shift+,` to free that chord for cmux). For a quick reference of invocation and keybindings, see `docs/tldrs/ghostty.md` (when authored).

## Appearance baseline

```toml
theme = Nord Wave                # +list-themes | grep -i nord for variants
font-family = MesloLGS Nerd Font Mono
font-size = 15
cursor-style = block
cursor-style-blink = false

font-thicken = true              # firms up text on retina without going bold
font-thicken-strength = 1        # 1 = lightest thickening (255 = max)
adjust-cell-height = 1           # 1px vertical breathing room

bold-is-bright = true            # bright ANSI codes render as bright (p10k, ls --color)
```

`font-thicken-strength` higher than 1 starts looking aggressive at 15pt+. Step up for smaller fonts; back off at 18pt+.

## Window chrome

```toml
window-padding-x = 8
window-padding-y = 6
window-padding-balance = true        # equalize when cells don't divide evenly
window-save-state = always           # restore tabs/splits on relaunch
window-inherit-working-directory = true
window-inherit-font-size = true

background-opacity = 0.96
background-blur = 20                 # macOS native vibrancy, 0-100
unfocused-split-opacity = 0.85

window-colorspace = display-p3       # Apple Silicon Retina wide-gamut
resize-overlay = after-first         # size hint only after first drag
window-step-resize = true            # cell-snap on drag-resize (macOS)
window-new-tab-position = end        # browser-convention tab placement
```

`window-colorspace = display-p3` matters for color-managed themes; Nord is defined in sRGB so colors shift slightly under display-p3 rendering. Verify visually and switch to `srgb` if the palette looks off.

`window-save-state = always` lets `confirm-close-surface = false` ride: kill the window, relaunch, tabs/splits restored.

## macOS-native integration

```toml
macos-titlebar-style = transparent       # tabs break under non-native fullscreen
macos-non-native-fullscreen = padded-notch    # MBP notch-aware
macos-option-as-alt = left               # left-Option = Meta; right keeps € ç etc.
macos-window-shadow = true
```

`macos-titlebar-style = hidden` is the chromeless alternative — more screen, no tabs visible. Pick one per the tab vs screen-real-estate trade.

## Quick terminal (drop-down)

```toml
keybind = global:cmd+§=toggle_quick_terminal
quick-terminal-position = top
quick-terminal-size = 100%,40%           # full width, 40% height
quick-terminal-screen = mouse
quick-terminal-animation-duration = 0.12
quick-terminal-autohide = true
```

`cmd+§` is the ISO key above Tab on Czech/UK/EU layouts — unclaimed by macOS, leaves bare § typing intact elsewhere. US/QWERTY users without § pick another unused global chord (e.g. `cmd+ctrl+space`).

**One-time setup**: System Settings → Privacy & Security → Accessibility → toggle on for Ghostty, then fully quit and relaunch. `reload-config` does NOT pick up new global bindings. cmux lacks a quick-terminal equivalent; Ghostty stays installed for this drop-down alone.

## Shell integration + SSH

```toml
shell-integration = detect
shell-integration-features = cursor,sudo,title,ssh-env,ssh-terminfo
scrollback-limit = 100000000             # ~100MB; Claude Code emits a lot
```

`ssh-terminfo` installs `xterm-ghostty` on remote hosts on first SSH connection. `ssh-env` auto-downgrades TERM to `xterm-256color` when the remote lacks the ghostty terminfo. No `tic` dance, no manual `TERM=xterm-256color ssh ...`.

## Kitty keyboard protocol — the agreement chain

Three layers must agree to forward modifier-rich keystrokes (Alt+Arrow, Shift+Tab, Ctrl+Tab) into the inner editor:

| Layer            | Setting                                                                          |
| ---------------- | -------------------------------------------------------------------------------- |
| Ghostty (outer)  | Kitty protocol on by default in 1.x. `macos-option-as-alt` must stay consistent. |
| tmux (middle)    | `extended-keys on` + `terminal-features 'xterm*:extkeys'` (see TmuxToolkit).      |
| Inner editor     | helix `keyboard-protocol = "kitty"`, neovim equivalent `:set`.                    |

Any disagreement collapses modifier reporting silently. See the "trap zones" section below for the macos-option-as-alt + extkeys clash.

## OSC 8 hyperlink hover

```toml
link-previews = osc8                     # hover preview only for explicit OSC 8 links
```

Default `true` regex-scans every visible line on cursor move, which is noticeable in long buffers. `osc8` limits hover previews to explicit OSC 8 hyperlinks (emitted by `gh`, modern shells, `eza`, build tools). Plain text URLs stay Cmd-clickable; only the popover hover preview goes away for them.

## Mouse + clipboard

```toml
mouse-hide-while-typing = true
mouse-shift-capture = false              # Shift+click escapes to tmux/vim selection
copy-on-select = clipboard
clipboard-paste-protection = true        # warn on multi-line / control-char paste
clipboard-paste-bracketed-safe = true    # auto-trust bracketed-paste-aware apps
```

`mouse-shift-capture = false` is load-bearing for tmux: it lets Shift+click bypass tmux's mouse-on capture and use Ghostty's native selection. Without it, Cmd+click and Cmd+Shift+click both end up captured by tmux.

`copy-on-select = clipboard` writes selections to the system clipboard immediately — no explicit Cmd+C needed. Trailing whitespace is trimmed by Ghostty's default `clipboard-trim-trailing-spaces = true`; no leading-whitespace trim is available.

## Notifications

```toml
notify-on-command-finish = unfocused
notify-on-command-finish-after = 10s
```

macOS notification fires when a foreground command exits in an *unfocused* Ghostty window after the threshold. Useful for long-running tests, builds, code reviews where you've task-switched away. Set to `always` if you want the notification even on focused windows; `never` to disable entirely.

## Custom keybinds (over the 1.3+ defaults)

Ghostty 1.3+ defaults cover splits (`cmd+d` / `cmd+shift+d`), split navigation (`cmd+alt+arrows`), split zoom (`cmd+shift+enter`), split resize (`cmd+ctrl+arrows`), equalize (`cmd+ctrl+=`), tab navigation (`cmd+shift+[/]`), tab jump (`cmd+1..9`), prompt jump (`cmd+shift+up/down` via shell-integration), clear (`cmd+k`), command palette (`cmd+shift+p`). `ghostty +list-keybinds --default` enumerates the full set.

```toml
keybind = cmd+shift+r=reload_config      # over Ghostty's default cmd+shift+,
keybind = shift+enter=text:\n            # multi-line input when kitty negotiation misses
```

`shift+enter=text:\n` is the workaround for Claude Code multi-line input under older Claude Code, nested tmux, or SSH without extkeys. Modern stack with kitty-protocol forwarding makes this redundant; keep as belt-and-braces.

## Three Ghostty + tmux trap zones

Diagnostic — apply only if the symptom is observed.

### Cmd+1-9 routes to Ghostty tabs

Default behavior: `cmd+1..9` jumps to Ghostty tab N. If tmux windows are the primary axis and you'd prefer `cmd+N` to send `prefix+N` (one keystroke vs two), rebind to send the tmux escape sequence directly. Tmux prefix `Ctrl+B` is `\x02`:

```toml
keybind = cmd+one=text:\x021
keybind = cmd+two=text:\x022
# ... cmd+three through cmd+nine
```

Source: <https://github.com/ghostty-org/ghostty/discussions/8756>

### Alt+Arrow word-jump regression under tmux+extkeys

Test: in nvim inside tmux, does Option+Left move by word? If broken (beeps, garbage characters), Ghostty's Alt+Arrow handlers are eating the event before it reaches tmux. Unbind on the Ghostty side so the keys forward cleanly:

```toml
keybind = alt+left=unbind
keybind = alt+right=unbind
```

Source: <https://github.com/ghostty-org/ghostty/discussions/2845>

### `macos-option-as-alt` + `extkeys` mismatch (Ghostty 1.2.3+)

tmux emits xterm format `ESC[27;2;13~` while kitty-protocol-aware apps expect `ESC[13;2u`. Symptom: modifier+key combos behave inconsistently inside tmux vs outside. Fix on the tmux side, not the Ghostty side:

```tmux
# either:
set -s extended-keys always              # force xterm format everywhere
# OR drop extkeys from terminal-features in tmux.conf and accept the
# capability loss for inner TUIs that wanted extended-keys.
```

Source: <https://github.com/ghostty-org/ghostty/discussions/9340>

## Extension surface

Ghostty has no plugin system. The extension points:

- **Themes** — `~/.config/ghostty/themes/<name>` (same syntax as the main config)
- **Custom shaders** — `custom-shader = /path/to/file.glsl` (repeat to stack). Catalogues: [0xhckr/ghostty-shaders](https://github.com/0xhckr/ghostty-shaders), [thijskok/ghostty-shaders](https://github.com/thijskok/ghostty-shaders)
- **Config includes** — `config-file = path` (`?path` for silent-if-absent, useful for machine-local overrides)
- **Keybind chords** — `>` separator (e.g. `ctrl+a>n=new_tab`)

Machine-local pattern:

```toml
config-file = ?local.conf                # silent if absent; for laptop-vs-desktop font-size tweaks
```

## Common pitfalls

| Symptom                                                 | Cause / Fix                                                                                       |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Trailing comments on config lines break parsing         | Ghostty parses `key = value # comment` as `value = "...# comment"`. Put comments on their own line. |
| Quick terminal binding does nothing after install       | Privacy & Security → Accessibility wasn't toggled on for Ghostty, or app wasn't fully restarted.   |
| URL Cmd+click hover is laggy in long buffers           | `link-previews = true` regex-scans every visible line. Set `link-previews = osc8`.                |
| Cmd+click on URL inside tmux does nothing               | tmux `mouse on` captures the click. Use Cmd+Shift+click to hand it back to Ghostty.               |
| Multi-line input broken in Claude Code (older versions) | Add `keybind = shift+enter=text:\n` to inject a literal newline.                                  |
| Nord theme colors look slightly off                    | `window-colorspace = display-p3` shifts sRGB-defined themes. Switch to `srgb` if it bothers.       |
| tic + ssh complaints about `xterm-ghostty` on remotes  | `shell-integration-features` missing `ssh-terminfo` and `ssh-env`. Add both.                       |

## Reload after edit

```sh
# In-app: cmd+shift+r (custom; default is cmd+shift+,)
# CLI: ghostty +reload-config           # works for non-global bindings only
```

Global keybinds (`keybind = global:...`) require a full app restart, not just config reload, to take effect.
