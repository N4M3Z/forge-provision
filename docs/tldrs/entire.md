# entire

AI-session checkpoint + resume for Claude Code (entireio/cli, Nat Friedman, MIT). Captures the full transcript onto a per-session git branch via Claude hooks, anchored to the commits it produced. **Two layers: local checkpoint/session (works offline) and a cloud layer — recap, activity, search, dispatch — gated behind `entire login`.** See [ARCH-0028](../decisions/ARCH-0028%20Session%20persistence%20Entire%20CLI.md).

## Local commands (no login)

| Command | Effect |
|---|---|
| `entire status` | Enabled/disabled, strategy, branch for the current repo |
| `entire enable --agent claude-code --skip-push-sessions --local --telemetry=false` | Enable in current repo, public-repo-safe (transcript never pushed) |
| `entire disable` | Disable in current repo (checkpoints stay on their branch) |
| `entire agent list` | Which agent hooks are installed (`✓ claude-code`) |
| `entire session list` | All tracked sessions: first prompt, status, age, tokens |
| `entire session current` | Active session for the current worktree |
| `entire session info <id> [--json]` | Full detail for one session |
| `entire session resume <branch>` | Switch to a branch and resume its Claude session (robust, branch-anchored) |
| `entire session attach <id>` | Capture a pre-existing/unhooked session into a checkpoint |
| `entire checkpoint list` (`cp`) | Timeline of checkpoints on the current branch, labelled by prompt/agent action |
| `entire checkpoint explain <id\|sha>` | What a checkpoint, commit, or session did |
| `entire checkpoint rewind --to <id>` | Browse and restore working tree + session to a checkpoint |
| `entire doctor` | Diagnose why a session isn't being captured |
| `entire clean` | Clean up Entire session data |

## Cloud commands (need `entire login`)

| Command | Effect |
|---|---|
| `entire login` / `entire auth status` | Authenticate / check auth |
| `entire recap [--day\|--week\|--month\|--90] [--static]` | Summarize recent checkpoint activity (standup) |
| `entire activity` | Activity overview |
| `entire checkpoint search "<query>"` | Semantic + keyword search across sessions (long-term memory) |
| `entire dispatch` | Generate a summary of recent agent work (PR / handoff) |
| `entire plugin {install\|list\|remove}` | Manage Entire plugins |
| `entire labs` | Experimental workflows |

`entire checkpoint search --json` is what the `entire-search` agent shells out to.

## Resume beats native `claude --resume`

Native resume keys on the encoded cwd-hash, so resuming from a different path silently forks a new session (the failure mode that wastes time in cmux). `entire session resume <branch>` is **branch-anchored** — it restores the exact session tied to a branch, then hands off to `claude --resume <id>`. Same fidelity, robust selection.

## How capture works (verified on disk)

Claude hooks fire on `Task` pre/post (every subagent boundary), `TodoWrite`, and session start/end. Each fire commits a checkpoint onto the per-session **`entire/<hash>`** branch, labelled with the prompt and carrying `Entire-Session` / `Entire-Strategy` trailers. Each commit appends the new turns to `.entire/metadata/<session-id>/full.jsonl` (the diff between two checkpoints *is* the conversation between them), with `prompt.txt` and per-task `tasks/<toolu>/checkpoint.json` records. So capture is finer than your own commits — nothing is lost between them.

`entire/checkpoints/v1` is a separate metadata-init branch (empty tree), **not** where transcripts live.

## State locations

| Path | Contents |
|---|---|
| `entire/<hash>` branch | Per-session transcript (`full.jsonl`) + prompt + per-task checkpoints |
| `.entire/settings.local.json` | Per-repo config (gitignored via `--local`) |
| `.claude/settings.json` | The installed Claude hooks (Task/TodoWrite/session) |
| `~/.claude/projects/.../<id>.jsonl` | Claude's own append-only transcript (Entire's source) |

## Common pitfalls

| Symptom | Cause / Fix |
|---|---|
| `recap`/`activity`/`search`/`dispatch` fail with TLS / "not logged in" | Cloud layer — run `entire login`. Needs network to entire.io. |
| `checkpoint list` says "Entire is disabled" | The repo is disabled (`entire status` to confirm); `entire enable …` to re-enable. |
| Transcript would leak on a public repo | `push_sessions` defaults to `true`. Always enable with `--skip-push-sessions`; verify `.entire/settings.local.json` shows `"push_sessions": false`. |
| Every agent prompt asks for a YubiKey touch | Checkpoint commits inherit `commit.gpgsign`. Optional `entire` wrapper that sets `GIT_CONFIG_*` to disable signing for Entire's process only. |
| Session started before enabling isn't captured | `entire session attach <id>` backfills it. |

## Config + provisioning

- Install: `brew tap entireio/tap && brew install --cask entire`
- Enable per repo: `entire enable --agent claude-code --skip-push-sessions --local --telemetry=false`
- Cross-machine resume needs a **private** `checkpoint_remote` (`entire configure --checkpoint-remote github:org/private-checkpoints`), never the public origin — deferred per ARCH-0028.

## Sources

- [entireio/cli](https://github.com/entireio/cli) · [docs](https://docs.entire.io) · [security model](https://docs.entire.io/security) · [configuration](https://docs.entire.io/cli/configuration)
- [ARCH-0028 Session persistence Entire CLI](../decisions/ARCH-0028%20Session%20persistence%20Entire%20CLI.md)
