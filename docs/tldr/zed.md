# Zed

GPU-native, AI-first editor with git, terminal, vim mode, and collaboration built in, so the extension surface stays small. Claude Code runs inside its agent panel over the Agent Client Protocol ([external agents][ACP]), which makes Zed the GUI lane for the same agent that owns the terminal lane.

## Install

```sh
brew install --cask zed          # or scripts/install/brew-bundle.sh
./scripts/configure/zed.sh       # deploy settings.json + keymap.json
```

The cask links the bundled CLI (`Zed.app/Contents/MacOS/cli`) as `zed`; no in-app "install cli" step ([cask source][CASK]).

## Paths

| Path | Role |
| --- | --- |
| `~/.config/zed/settings.json` | user settings, JSONC ([configuring][CONF]) |
| `~/.config/zed/keymap.json` | user keymap, layers over `base_keymap` ([keys][KEYS]) |
| `~/.config/zed/tasks.json` | task definitions, `$ZED_FILE` / `$ZED_WORKTREE_ROOT` vars ([tasks][TASKS]) |
| `.zed/settings.json` | per-project overrides (defaults < user < project) |
| `~/Library/Application Support/Zed/` | extensions + state; never track in dotfiles ([extensions][EXT]) |

Copy configs, never symlink: in-app settings edits replace the file atomically and sever the link ([#4469][I4469]).

## Config decisions baked into the manifest

- AI lanes: Claude Code declared under `agent_servers` as a custom ACP agent (`npx -y @zed-industries/claude-code-acp`, [adapter][ACPNPM]), so the agent panel works with zero per-machine setup; auth stays with Claude Code. Edit predictions ride the default provider, Zeta, which activates after a one-time Zed sign-in ([edit prediction][EP]).
- `theme`: Catppuccin Mocha / Latte in system mode, the most-downloaded community theme ([extension][CAT]); installed declaratively with everything else.
- `vim_mode` + `relative_line_numbers` + `cursor_blink: false`: the vim-docs recommended trio ([vim][VIM]). Surround, sneak, and exchange are built in.
- `telemetry` diagnostics + metrics off ([telemetry][TEL]).
- `auto_install_extensions`: theme plus language coverage matched to the machine's stack (toml, make, dockerfile, docker-compose, sql, env, csv, lua, basher, git-firefly, markdown-oxide, html). Declarative, applied at startup; no extension CLI exists ([#10943][I10943]). Every id verified against the [extension registry][REG].
- Space-leader keymap (`space space` file finder, `space e` project panel, `space g` git panel) under `VimControl && !menu`, the context Zed's own vim keymap uses ([keymap source][VIMKEYS]).
- `terminal.font_family`: MesloLGS Nerd Font Mono, same family string Ghostty uses, so prompt glyphs render single-cell in both terminals.
- Markdown `format_on_save: off`: formatters mangle reference-style links.

## Agent panel

The manifest's `agent_servers` entry is the wiring; nothing to install in-app. Alternatives: the ACP registry (`zed: acp registry` command) installs Zed-managed agents, and `context_servers` configures MCP servers (`{command, args, env}` local or `{url, headers}` remote) ([mcp][MCP]). Native agent-panel models need API keys (`ANTHROPIC_API_KEY` from the environment beats keychain, [api access][API]); the Claude Code lane needs none of that.

## Notes

- Settings are JSONC; `jq` chokes on the comments. Strip first or keep tooling away.
- No native settings sync ([#6569][I6569]); this repo's manifest copy is the sync.
- ThePrimeagen never switched (still Neovim); Theo sampled it twice without publishing a config. The substantive creator material is Syntax.fm [episode 948][SYNTAX] and Zed dev dotfiles ([Thorsten Ball][MRNUGGET]).

[ACP]: https://zed.dev/docs/ai/external-agents "Zed docs, External Agents"
[ACPNPM]: https://www.npmjs.com/package/@zed-industries/claude-code-acp "claude-code-acp adapter"
[API]: https://zed.dev/docs/ai/use-api-access "Zed docs, API access"
[CASK]: https://github.com/Homebrew/homebrew-cask/blob/master/Casks/z/zed.rb "Homebrew cask: zed"
[CAT]: https://zed.dev/extensions/catppuccin "Catppuccin for Zed"
[CONF]: https://zed.dev/docs/configuring-zed "Zed docs, Configuring Zed"
[EP]: https://zed.dev/docs/ai/edit-prediction "Zed docs, Edit Prediction"
[EXT]: https://zed.dev/docs/extensions/installing-extensions "Zed docs, Installing Extensions"
[I10943]: https://github.com/zed-industries/zed/issues/10943 "zed#10943, extension install CLI request"
[I4469]: https://github.com/zed-industries/zed/issues/4469 "zed#4469, settings save replaces symlink"
[I6569]: https://github.com/zed-industries/zed/discussions/6569 "zed discussion #6569, settings sync"
[KEYS]: https://zed.dev/docs/key-bindings "Zed docs, Key Bindings"
[MCP]: https://zed.dev/docs/ai/mcp "Zed docs, Model Context Protocol"
[MRNUGGET]: https://github.com/mrnugget/dotfiles/blob/master/zed_settings.json "Thorsten Ball's Zed settings"
[REG]: https://github.com/zed-industries/extensions/blob/main/extensions.toml "Zed extension registry"
[SYNTAX]: https://syntax.fm/show/948 "Syntax.fm 948, Zed is Ready For Primetime"
[TASKS]: https://zed.dev/docs/tasks "Zed docs, Tasks"
[TEL]: https://zed.dev/docs/telemetry "Zed docs, Telemetry"
[VIM]: https://zed.dev/docs/vim "Zed docs, Vim Mode"
[VIMKEYS]: https://github.com/zed-industries/zed/blob/main/assets/keymaps/vim.json "Zed vim keymap source"
