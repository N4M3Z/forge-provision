# revdiff

Terminal TUI for AI-session diff review with inline annotations. Local diffs only — does not post to GitHub PRs.

## Invocation

| Command | What it does |
|---|---|
| `revdiff` | Uncommitted changes (working tree) |
| `revdiff --untracked` | Uncommitted + new files (default in chezmoi-managed config) |
| `revdiff --staged` | Staged hunks only |
| `revdiff HEAD~1` | Diff against one commit ago |
| `revdiff main feature` | Compare two refs |
| `revdiff --all-files -X vendor` | Browse every tracked file, excluding `vendor/` |
| `revdiff README.md` | Single-file review (`--only=<path>`) |
| `cat file \| revdiff --stdin` | Review piped content |
| `revdiff --dump-config` | Print default config (paste into `~/.config/revdiff/config`) |
| `revdiff --dump-keys` | Print default keybindings |
| `revdiff --list-themes` | List bundled themes |

## In-session keys

| Key | Action |
|---|---|
| `t` | Toggle tree panel visibility (gitui-style) |
| `tab` | Cycle focus between tree and diff |
| `h` / `l` | Vim focus: tree / diff |
| `←` / `→` | Focus tree / diff (custom remap; default is horizontal scroll) |
| `j` / `k` or `↑` / `↓` | Cursor up / down |
| `n` / `N` or `p` | Next / prev file |
| `[` / `]` | Prev / next hunk (crosses files with `cross-file-hunks = true`) |
| `a` or `enter` | Annotate current line |
| `A` | Annotate file (file-level note, not line-anchored) |
| `d` | Delete annotation under cursor |
| `@` | List all annotations |
| `space` | Mark file reviewed |
| `f` | Filter files |
| `/` | Search |
| `v` | Toggle collapsed mode (final text + change markers, no add/remove bg) |
| `C` | Toggle compact mode (small context around changes) |
| `w` | Toggle line wrap |
| `L` | Toggle line numbers |
| `B` | Toggle blame gutter |
| `W` | Toggle word-diff |
| `.` | Toggle current hunk |
| `u` | Toggle untracked |
| `T` | Theme picker (live A/B in-session) |
| `i` | Info popup (shows `--description=` content) |
| `R` | Reload diff |
| `q` | Quit and emit annotations to stdout |
| `Q` | Discard annotations and quit |
| `?` | Help overlay |

## Config

Canonical source: `dotfiles/dot_config/revdiff/config` (chezmoi-managed, deploys to `~/.config/revdiff/config`).

Custom keybindings: `dotfiles/dot_config/revdiff/keybindings` (chezmoi-managed). Format is `map <key> <action>` and `unmap <key>`; overrides layer on defaults. Run `revdiff --dump-keys` for the full action list.

## Green-background fix

If 100%-new files flood the screen with green, override the Nord theme bg in `[color options]`:

```ini
color-add-bg =
color-remove-bg =
```

Empty falls back to terminal default. The `+` / `-` gutter and `color-add-fg` still carry the signal.

Alternative: press `v` in-session for collapsed mode — shows post-change file with marker gutter only, no bg flood at all.
