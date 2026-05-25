# cmux

libghostty-based AI-pane manager for parallel Claude Code (and other agent) sessions on macOS. **Workspace-per-Claude-session is the load-bearing model** — sidebar shows branch + PR + ports + latest notification per workspace.

## Invocation

| Command                          | Effect                                                                                  |
| -------------------------------- | --------------------------------------------------------------------------------------- |
| `cmux`                           | Launch the app                                                                          |
| `cmux restore-session`           | Reapply the last saved snapshot manually                                                |
| `cmux ssh <host>`                | Open an ssh surface                                                                     |
| `cmux claude-hook`               | Hook entry point Claude Code calls (set up by `cmux hooks setup`)                       |
| `cmux hooks setup`               | Wire Claude Code lifecycle hooks into `~/.claude/settings.json`. Run once after install. |
| `cmux surface resume set "<cmd>"` | Pin a resume command for the active surface                                            |
| `cmux surface resume show`       | Show what's pinned                                                                      |
| `cmux surface resume clear`      | Release the pin                                                                         |
| `cmux --version`                 | Version check                                                                           |

## Keybindings (in our `dot_config/cmux/cmux.json`)

| Key                                       | Action                                                                                  |
| ----------------------------------------- | --------------------------------------------------------------------------------------- |
| `Cmd+Shift+R`                             | Reload config (rebound from default `Cmd+Shift+,` for Ghostty muscle memory)            |
| `Cmd+Shift+U`                             | Jump to most-recent unread workspace                                                    |
| `Cmd+Shift+I`                             | Open notification panel                                                                 |
| `File → Reopen Previous Session` / `Cmd+Shift+O` | Reapply last snapshot                                                            |

Default chord set is otherwise close to Ghostty — splits, tab nav, etc. `cmux --list-keybinds` enumerates.

## Persistence — what survives, what doesn't

| Event             | What survives                                                                                                                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| cmux quit (Cmd+Q) | Layout, cwd, scrollback (best-effort), browser URLs. Live processes die unless they're a supported AI agent (Claude Code, Codex, Cursor CLI, Gemini, Amp) — those resume via captured session IDs.                       |
| cmux crash        | Same as quit, with snapshot-overwrite caveats ([#2895][I2895], [#2745][I2745], [#2387][I2387]).                                                                                                                          |
| Laptop reboot     | Layout maybe restored; processes gone. Snapshot can lose workspaces. For durable process state, layer tmux inside a cmux pane.                                                                                            |

Snapshot lives at `~/Library/Application Support/cmux/`. Per-agent session mappings at `~/.cmuxterm/`. There is no explicit close/archive/resume-by-name command — [#2086][I2086] tracks the feature request.

## Claude Code hook integration

After `cmux hooks setup`, three hooks fire per Claude session:

| Hook            | Effect                                                                                       |
| --------------- | -------------------------------------------------------------------------------------------- |
| `session-start` | Writes session ID to `~/.cmuxterm/` so cmux can route notifications back                      |
| `notification`  | Surfaces a sidebar badge + unread ring on the originating workspace                           |
| `stop`          | Marks the session as idle in the sidebar                                                      |

This is how the sidebar knows which workspace produced which notification, and how cmux can resume the correct Claude session by ID (rather than relying on Claude's per-cwd session storage).

## Common pitfalls

| Symptom                                                      | Cause / Fix                                                                                                                                                                                  |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claude --resume` from a fresh shell drops you into the wrong session | Claude Code keys sessions by cwd-hash; cmux keys by workspace-tracked session ID. Use `cmux surface resume set "claude --resume <session-id>"` to pin the right one, or pass the explicit ID. |
| Workspaces vanished after laptop restart                     | [#2895][I2895] / [#2745][I2745] snapshot-overwrite bug. Back up `~/Library/Application Support/cmux/session-*.json` if it matters.                                                            |
| Long-running build watch died on cmux quit                   | Live processes don't persist. Run inside `tmux` inside the cmux pane for cross-quit continuity; add `tmux-resurrect` + `tmux-continuum` for cross-reboot.                                     |
| `Cmd+Shift+,` doesn't reload config                          | Overridden in our config to `Cmd+Shift+R`.                                                                                                                                                   |
| `cmux` CLI not on PATH                                       | `scripts/install/cmux.sh` symlinks `<App>/Contents/Resources/bin/cmux` → `~/.local/bin/cmux`. Verify `~/.local/bin` is in PATH.                                                              |

## Notable config baked in

- `matchTerminalBackground: true` — sidebar bg follows Ghostty's terminal background
- `indicatorStyle: "leftRail"` — thin colored bar + subtle tinted bg for active workspace
- `selectionColor: "#5E81AC"` — Nord Frost Deep accent
- `notifications: { dockBadge, showInMenuBar, unreadPaneRing, paneFlash, sound: "default" }`
- `sidebar.branchLayout: "vertical"` — vertical branch list per workspace

## Config + reload

- Canonical: `~/Developer/N4M3Z/dotfiles/dot_config/cmux/cmux.json`
- Deployed: `~/.config/cmux/cmux.json`
- Deploy: `chezmoi apply ~/.config/cmux/cmux.json`
- Reload running app: `Cmd+Shift+R` (rebound). Global keybinds require full app restart, not config reload.

## Sources

- [manaflow-ai/cmux][REPO]
- [cmux docs (Mintlify)][DOCS]
- [Claude Code integration][CCINT]
- [cmux.json schema][SCHEMA]
- [Issue #2086 — named session save/restore][I2086]
- [Issue #2895 — snapshot overwrite][I2895]
- [Lawrence Chen (founder) on X][LC]

[REPO]: https://github.com/manaflow-ai/cmux
[DOCS]: https://cmux.com/docs
[CCINT]: https://manaflow-ai-cmux.mintlify.app/integrations/claude-code
[SCHEMA]: https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json
[I2086]: https://github.com/manaflow-ai/cmux/issues/2086
[I2895]: https://github.com/manaflow-ai/cmux/issues/2895
[I2745]: https://github.com/manaflow-ai/cmux/issues/2745
[I2387]: https://github.com/manaflow-ai/cmux/issues/2387
[LC]: https://x.com/lawrencecchen
