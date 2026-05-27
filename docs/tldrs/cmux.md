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
| `cmux claude-teams [claude-args]` | Launch Claude with agent teams visible as sidebar splits (tmux shim). Accepts any claude flag (`--resume`, `--continue`, `--model`). |
| `cmux --version`                 | Version check                                                                           |

## Shell integration

The `claude()` function in `dot_zshrc` routes invocations by environment:

```
cmux detected (CMUX_SURFACE_ID set) → cmux claude-teams "$@"
    Agent teams spawn as visible vertical splits with sidebar metadata.
outside cmux, no tmux                  → tmux new-session -A -s claude "command claude"
    Wraps in a persistent tmux session for Ghostty restarts.
otherwise (args passed, or in tmux)    → command claude "$@"
    Bare binary, no wrapping.
```

Three env vars cmux injects per pane: `CMUX_SURFACE_ID` (pane identity), `CMUX_WORKSPACE_ID` (workspace identity), `CMUX_SOCKET_PATH` (socket for CLI API).

The cmux claude wrapper at `/Applications/cmux.app/Contents/Resources/bin/claude` injects 6 hooks via `--settings` (SessionStart, Stop, SessionEnd, Notification, UserPromptSubmit, PreToolUse). Opt out with `CMUX_CLAUDE_HOOKS_DISABLED=1` if a Claude Code update breaks the wrapper ([#3059](https://github.com/manaflow-ai/cmux/issues/3059)).

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

State locations:

| Path                                       | Contents                                                                                          |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `~/Library/Application Support/cmux/`      | Socket (`cmux.sock`), search DB (SQLite FTS), session restore JSON (workspace layouts + session IDs) |
| `~/.cmuxterm/`                             | Claude-teams tmux shim, hook session tracking (`claude-hook-sessions.json`), event telemetry       |
| `~/.config/cmux/cmux.json`                 | User config (chezmoi-managed)                                                                     |

No explicit close/archive/resume-by-name command — [#2086][I2086] tracks the feature request. [crex](https://github.com/drolosoft/cmux-resurrect) fills the gap externally.

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

## Layout templates (commands[])

`commands[]` in cmux.json defines workspace layout recipes invokable from the Command Palette (`Cmd+Shift+P`) or the plus-button menu. Each entry creates a named workspace with a pre-defined pane arrangement. Think tmuxinator but declarative JSON.

```jsonc
"commands": [
    {
        "name": "Split Workspace",
        "workspace": {
            "layout": {
                "direction": "horizontal",   // "horizontal" or "vertical"
                "split": 0.5,                // ratio (0.0-1.0)
                "children": [
                    { "surface": { "type": "terminal" } },
                    { "surface": { "type": "terminal" } }
                ]
            }
        }
    }
]
```

Layouts nest recursively: a child can be another split node (with its own `direction`, `split`, `children`) or a leaf surface (`terminal` or `browser` with optional `command`, `url`, `cwd`, `env`). Structural templates don't reference versions or APIs, so they're durable across cmux updates (`schemaVersion` guards breakage). See [cmux custom commands docs][CMDS].

`actions{}` is a separate registry (nightly, unstable) that wires buttons/shortcuts into the tab bar and Command Palette. Defer until the API stabilizes.

## Notable config baked in

- `matchTerminalBackground: true` — sidebar bg follows Ghostty's terminal background
- `workspaceColors.indicatorStyle: "leftRail"` — thin colored bar + subtle tinted bg for active workspace
- `workspaceColors.selectionColor: "#5E81AC"` — Nord Frost Deep accent
- `notifications: { dockBadge, unreadPaneRing }` on; `paneFlash` + `sound` off (fatigue reduction)
- `sidebar.branchLayout: "vertical"` — vertical branch list per workspace
- `app.commandPaletteSearchesAllSurfaces: true` — cross-workspace search in Cmd+Shift+P
- `app.openMarkdownInCmuxViewer: true` — .md files render in cmux's viewer
- `terminal.agentHibernation: { enabled, idleSeconds: 1800, maxLiveTerminals: 8 }` — suspends idle agents after 30 min

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
- [Custom commands docs][CMDS]

[REPO]: https://github.com/manaflow-ai/cmux
[CMDS]: https://cmux.com/docs/custom-commands
[DOCS]: https://cmux.com/docs
[CCINT]: https://manaflow-ai-cmux.mintlify.app/integrations/claude-code
[SCHEMA]: https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json
[I2086]: https://github.com/manaflow-ai/cmux/issues/2086
[I2895]: https://github.com/manaflow-ai/cmux/issues/2895
[I2745]: https://github.com/manaflow-ai/cmux/issues/2745
[I2387]: https://github.com/manaflow-ai/cmux/issues/2387
[LC]: https://x.com/lawrencecchen
