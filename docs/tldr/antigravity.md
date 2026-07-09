# Antigravity

Google's terminal coding agent ([product page][AGY]), run as a third independent cross-reviewer alongside Claude Code and Codex. It is chosen over the earlier `gemini-cli`, which Google restricted for personal Google accounts; `agy` serves the same personal plan. The CLI reuses the `~/.gemini/` config root.

## Install

```sh
brew install --cask antigravity-cli   # provides `agy`, self-updating
brew install --cask antigravity       # the desktop app (agent-orchestration platform)
./scripts/configure/gemini.sh         # seed ~/.gemini/config/mcp_config.json if absent
agy                                    # launch, then sign in with a Google account
```

Vendor installer without Homebrew (Linux, or brew-free macOS); lands `agy` in `~/.local/bin`:

```sh
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

The `antigravity` app and the `agy` CLI are separate products that share the `~/.gemini/` config root and the same Google sign-in; the `antigravity-ide` editor is a third product, not installed here.

Verify auth and MCP wiring:

```sh
agy -p "reply with the word READY"     # confirms the plan serves the CLI
agy -p "list your MCP servers"         # confirms mcp_config.json loaded
```

## Paths

| Path | Role |
| --- | --- |
| `~/.gemini/config/mcp_config.json` | MCP servers; **chezmoi-owned** live (`dot_gemini/config/mcp_config.json`) |
| `~/.gemini/antigravity-cli/settings.json` | telemetry, terminal sandbox, trusted workspaces; **app-managed**, not tracked |
| `~/.gemini/config/config.json` | remote-control hostname; app-managed |
| forge-provision `manifests/gemini/mcp_config.json` | generic seed, empty `mcpServers`, not a mirror of live |

## MCP configuration

`mcp_config.json` uses the standard `{command, args, env}` schema under `mcpServers`. The generic seed is empty; the personal live file wires the local knowledge brain (gbrain) as one server:

```json
{
    "mcpServers": {
        "gbrain": {
            "command": "/opt/homebrew/bin/bun",
            "args": ["/Users/<user>/.bun/bin/gbrain", "serve"],
            "env": {
                "OPENAI_BASE_URL": "http://localhost:11434/v1",
                "OPENAI_API_KEY": "ollama",
                "DATABASE_URL": "postgresql://<user>@localhost:5432/memex",
                "PATH": "/Users/<user>/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"
            }
        }
    }
}
```

Absolute command paths, the Postgres role in `DATABASE_URL`, and an explicit `PATH` are required: the CLI launches MCP servers in a clean environment, so a bare command name or a role-less URL fails there even when it works in an interactive shell.

## Seed, not mirror

The good defaults ship in the app's own `settings.json` (`enableTelemetry: false`, `enableTerminalSandbox: true`), which the app rewrites and whose `trustedWorkspaces` list churns per workspace. That file is deliberately left untracked. chezmoi owns only `mcp_config.json`, the one file with durable personal value; forge-provision ships the empty-`mcpServers` baseline for a fresh machine.

[AGY]: https://antigravity.google/product/antigravity-cli "Antigravity CLI"
