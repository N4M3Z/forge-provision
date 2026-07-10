# Codex

OpenAI's coding agent, run alongside Claude Code as an independent cross-reviewer. Two surfaces share `~/.codex/config.toml`: the **CLI** (`codex`, sandboxed) and the **desktop app** (`Codex.app`, adds Computer Use). The decision and the sandbox-parity rationale are in [PROV-0019][ADR].

## Install

```sh
brew install --cask codex       # CLI, Homebrew-pinned
brew install --cask codex-app   # desktop app, self-updating
./scripts/configure/codex.sh    # seed ~/.codex/config.toml if absent
./scripts/configure/rtk-hook.sh # Claude hook + Codex RTK instructions
codex login                     # interactive auth (ChatGPT or API key)
```

## Paths

| Path | Role |
| --- | --- |
| `~/.codex/config.toml` | config, TOML; **app-managed** once the desktop app runs ([reference][CFG]) |
| `~/.codex/auth.json` | credentials; secret, never tracked |
| `~/.codex/AGENTS.md` | global prose instructions the agent reads; carries RTK plus the Claude-equivalent policy |
| forge-provision `manifests/codex/config.toml` | curated seed (no personal bits), not a mirror of live |
| forge-provision `manifests/codex/AGENTS.md` | curated global policy source for daily-driver Codex |

The desktop app rewrites the live config (plugins, trusted-hook hashes, marketplaces, `model`), so the seed is the version-controlled truth, not the live file.

Codex can import Claude hooks into `~/.codex/hooks.json`, but imported hook behavior is not guaranteed to translate. `scripts/configure/codex.sh` removes only the unsupported `rtk hook claude` entry and a duplicate imported `dcg` when native Codex config already contains the guard. Other imported hooks are preserved.

## Cross-review

```sh
codex --profile review "review the staged diff"     # read-only, never-prompt
codex exec review                                    # headless review subcommand
```

The `review` profile is `sandbox_mode = "read-only"` + `approval_policy = "never"`, so it cannot edit and cannot prompt; it fails closed, preserving genuine disagreement instead of silently fixing.

## Config: what mirrors Claude, what doesn't

| Claude `sandbox.*` / policy | Codex | |
| --- | --- | --- |
| Seatbelt, `enabled` | `default_permissions = "workspace-local"` | same OS primitive |
| `network.allowedDomains` | `[permissions.workspace-local.network.domains]`, `mode = "limited"` | filtered egress |
| `allowLocalBinding` / `allowUnixSockets` | `permissions.workspace-local.network.allow_local_binding` / `.unix_sockets` | maps |
| `filesystem.allowWrite` | `[permissions.workspace-local.workspace_roots]` | maps |
| subprocess env scrub | `[shell_environment_policy]` | maps |
| dcg PreToolUse hook | `[[hooks.PreToolUse]] command = "dcg"` | same guard |
| `permissions.defaultMode = "auto"` + `autoMode` | `approvals_reviewer = "auto_review"` + AGENTS.md | closest classifier analog |
| `filesystem.denyRead` | none | Seatbelt reads stay broad |
| `excludedCommands` | none | escalate via `approval_policy`; execpolicy is built-in, not authored |

gbrain is wired as `[mcp_servers.gbrain]` (personal layer). Validate any change with `codex doctor`.

## Integration ownership

| Integration | Codex wiring | Owner |
| --- | --- | --- |
| dcg | Native `PreToolUse` entry in `config.toml` | forge-provision / personal dotfiles |
| RTK | `AGENTS.md` includes `~/.codex/RTK.md`; no Claude rewrite hook | `rtk init -g --codex` via forge-provision |
| gbrain | MCP configuration plus local `gbrain` / `memex` CLI access | personal dotfiles |
| Entire | Project-local `.codex/hooks.json` lifecycle hooks | Entire itself |

Forge CLI deploys agents, skills, and rules. It intentionally does not own harness settings, imported hooks, MCP configuration, or third-party lifecycle installers.

## Policy model (both agents)

- **Soft, AI-judged (prose):** Claude's auto-mode `autoMode` block (`environment` / `soft_deny` / `hard_deny` / `allow`) + CLAUDE.md; Codex's `approvals_reviewer` + AGENTS.md. Prose rules, read by a classifier. A generated RTK-only AGENTS.md is too thin for daily-driver use.
- **Hard, structural (enforced):** `permissions.deny` (Claude) and dcg regex packs (both). These block regardless of the model's intent.

## Computer Use (desktop)

Drives arbitrary macOS apps by seeing and clicking. Gated behind macOS **Screen Recording + Accessibility** grants (TCC, granted by hand in System Settings, not scriptable). It runs **outside** the CLI sandbox and dcg, the highest-trust capability here, so grant it per-session, not broadly.

## Notes

- Config is TOML; `codex doctor` validates parse + effective sandbox/approval state.
- Keep local-model values such as `OPENAI_API_KEY = "ollama"` scoped to MCP env blocks, not global shell env. If `codex doctor` reports "mixed auth signals", Codex sees both ChatGPT login and an API-key env var.
- If Codex prints `could not create PATH aliases: Operation not permitted`, that is a sandboxed startup write attempt, not an MCP failure.
- Duplicate skills usually mean Codex is loading both `~/.codex/skills` and legacy `~/.agents/skills`. Prefer one canonical root; stale `.agents` copies can conflict with the newer `.codex` copies.
- The CLI is Homebrew-pinned; the desktop app self-updates (cask doesn't manage its version).
- dcg supports Codex (denials via stderr + exit 2) but ships no codex auto-installer; the hook block is the wiring, and Codex trusts it on first run via a recorded hash.
- RTK supports Codex through instructions, not transparent `PreToolUse` rewriting. Keep `rtk hook claude` confined to Claude Code.

[ADR]: ../decisions/PROV-0019%20Codex%20as%20a%20cross-reference%20coding%20agent.md "PROV-0019"
[CFG]: https://developers.openai.com/codex/config-reference "Codex configuration reference"
