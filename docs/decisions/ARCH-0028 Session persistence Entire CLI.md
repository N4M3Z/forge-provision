---
title: "Session persistence and resume: Entire CLI, commit-anchored, local-only on public repos"
description: AI coding sessions are preserved and resumed via Entire CLI, which checkpoints the full transcript onto a git branch tied to the commit it produced. Chosen over raw git-notes tools and a plain projects-dir sync. On public repos, push_sessions is disabled so transcripts never leak; cross-machine resume needs a private checkpoint remote and is deferred.
type: adr
category: tooling
tags:
    - sessions
    - persistence
    - resume
    - git
    - entire
    - privacy
status: accepted
created: 2026-06-01
updated: 2026-06-02
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0006 Commit signing.md"
    - "ARCH-0011 cmux as agent overlay on libghostty.md"
    - "ARCH-0014 Brewfile vs manual DMG criteria.md"
    - "ARCH-0026 Cross-session journaling bridge.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Session persistence and resume: Entire CLI, commit-anchored, local-only on public repos

## Context and Problem Statement

Claude Code sessions are append-only JSONL transcripts under `~/.claude/projects/<encoded-cwd>/<id>.jsonl`. Native `--resume` is fragile: it keys on the encoded current-working-directory, so resuming from a different path silently forks a new session, and sessions are otherwise lost on corruption, machine change, or accident. The goal: preserve a session durably, resume it tied to the commit it produced, and survive Claude's own session loss. Cross-harness resume (continuing a Claude session inside Codex/Gemini) was also wanted but is a separate, weaker capability.

The user explicitly rejected the [git-ai][GITAI] project and dislikes MCP-based solutions (they bloat every turn's context with tool schemas). The mechanism instinct was git notes — store the conversation in a note attached to the commit.

## Decision Drivers

- Durable, resumable conversation tied to the commit that produced it (provenance + resume in one).
- Survive native session loss and path-fragile `--resume`.
- **Public-repo safety**: `forge-provision` is a public GitHub repo. A transcript contains raw prompts, responses, file contents, internal paths — anything sensitive that passed through. Leaking it publicly is unacceptable.
- No MCP server (context-bloat aversion); prefer a CLI that shells out.
- Maintained tooling — not an abandoned single-author repo.
- Cross-machine resume desirable; cross-harness resume nice-to-have.

## Considered Options

1. **Raw git-notes conversation store (memento)** — [memento][MEMENTO] stores readable markdown transcripts directly in `refs/notes/*`, retrievable with `git notes show`. Closest to the original instinct, but slowing (last release mid-March 2026) with an open Claude Code v2.1.x compatibility break, and the GitHub 1MB note cap forces truncation on long sessions.
2. **git-ai** — rejected by the user. Stores only attribution in notes; transcripts moved to local SQLite / cloud since v1.0, so it is not a git-portable conversation store anyway.
3. **git-prompt-story** — stalled (5 stars, "not for public yet"); not viable.
4. **SpecStory** — alive, writes readable markdown to `.specstory/history/`, but anchoring to commits is manual and it commits files into the repo rather than a side branch.
5. **Plain sync of `~/.claude/projects/`** (rsync/syncthing/dedicated repo) — preserves the full multi-file DAG but has no commit anchor, no provenance, and is path-coupled (the encoded-cwd dir differs per machine, so resume needs a rehash/restore step regardless).
6. **Entire CLI** — [Entire][ENTIRE] (Thomas Dohmke, MIT, actively maintained). Checkpoints the full transcript onto a per-session `entire/<hash>` branch; resume restores Claude's native session log and prints `claude --resume <id>`. Branch-based storage sidesteps the 1MB note cap, the refspec footgun, and rebase-orphaning that plague the notes approach.

## Decision Outcome

Chosen option: **Entire CLI**, installed as a Homebrew cask ([ARCH-0014][DMG] governs install-path policy; Entire is a stable cask, not a rapid-ship DMG):

```sh
brew tap entireio/tap && brew install --cask entire
```

Enabled per-repo with privacy locked down at enable time:

```sh
entire enable --agent claude-code --skip-push-sessions --local --telemetry=false
```

- `--skip-push-sessions` sets `strategy_options.push_sessions: false` so the checkpoint branch (carrying the full transcript) is **never** pushed by a routine `git push`. This is mandatory on a public repo.
- `--local` writes Entire settings to `.entire/settings.local.json` (gitignored), keeping config out of tracked repo content. The Claude hooks land in the repo's `.claude/settings.json`; where that path is gitignored they do not reach the remote.
- Capture is event-driven, finer than your own commits. Claude hooks fire on `Task` pre/post (every subagent boundary), `TodoWrite`, and session start/end; each fire commits a checkpoint onto the per-session `entire/<hash>` branch, labelled with the prompt context and carrying `Entire-Session` / `Entire-Strategy` trailers. Each checkpoint commit appends the new turns to `.entire/metadata/<session-id>/full.jsonl` (the diff between two checkpoints *is* the conversation that happened between them), alongside `prompt.txt` and per-task `tasks/<toolu>/checkpoint.json` records. The branch named `entire/checkpoints/v1` is a separate metadata-init branch (empty tree), not where transcripts live. So no work is lost between *your* git commits — the transcript accrues continuously on the Entire branch. For a session that began before Entire was enabled, `entire session attach <session-id>` backfills a checkpoint from the existing JSONL.
- Resume restores the JSONL and hands off to native `claude --resume`, so fidelity equals Claude's own resume.

**Cross-harness resume is out of scope** — transcript formats and tool-call schemas do not transplant across harnesses. The viable cross-harness path is context re-injection (a distilled handoff or a tool like cli-continues), not live resume; that is a separate decision if pursued.

**Cross-machine resume is deferred** — it requires a dedicated **private** `checkpoint_remote` (never the public origin) and is not a documented happy path in Entire today.

**Checkpoint commit signing.** Checkpoint commits inherit the global `commit.gpgsign` ([ARCH-0006][SIGNING]), so each one asks for a YubiKey touch on every agent prompt, for a local record that needs no signature. Entire has no signing toggle. If this gets noisy, a fallback `entire` wrapper on `PATH` that turns `commit.gpgsign` off for Entire's process (via `GIT_CONFIG_*`) suppresses it without affecting your own commits. Kept as a workaround, not installed by default.

### Consequences

- [+] Full transcript captured into a commit-anchored checkpoint on a local branch.
- [+] Resume uses native `claude --resume` — no fidelity loss beyond what Claude itself provides.
- [+] Branch storage avoids the 1MB note cap, refspec config, and rebase-orphaning of the git-notes approach.
- [+] No MCP server; pure CLI + git hooks.
- [-] **Privacy is opt-out, not opt-in**: Entire defaults to `push_sessions: true` with the checkpoint remote = origin. On a public repo with defaults a normal push would publish the transcript. The `push_sessions: false` discipline is load-bearing and must be set at enable time.
- [-] Secret redaction is best-effort; PII redaction is a separate opt-in layer, disabled by default. Treat checkpoints as containing raw conversation.
- [-] Capture requires the session to be registered (hook-fired or `session attach`); a mid-session enable does not retroactively capture without `attach`.
- [-] The checkpoint captures the main transcript only, not the `<id>/` subagent sidecar — subagent detail is lost on resume (acceptable: the readable thread is what matters).
- [-] History rewrites (rebase, amend, squash-merge) orphan the commit↔checkpoint tracking — `entire status` flags "tracking diverged from current HEAD"; `entire doctor` reconciles the session branches without losing transcripts. Squash-merged mainline commits are GitHub-authored and carry no `Entire-Checkpoint` trailer, so commit-anchored explain is structurally unavailable on main in PR+squash repos; the tool's value concentrates in the active branch window (rewind, resume, handoff), not mainline archaeology.
- [-] Cross-machine and cross-harness resume are not delivered by this decision.
- [-] Checkpoint commits are signed by default like any commit; the fallback wrapper turns that off for Entire alone if it gets noisy.

## More Information

- [Entire CLI][ENTIRE] · [Entire security model][ENTIRESEC] · [Entire configuration][ENTIRECFG]
- [memento][MEMENTO] — git-notes readable-transcript precedent (evaluated, not chosen)
- [git-ai][GITAI] — rejected; attribution-in-notes, transcripts out of git since v1.0
- [ARCH-0026 Cross-session journaling bridge][JOURNAL] — complementary: work-log summaries to the vault, distinct from full-transcript resume
- [ARCH-0014 Brewfile vs manual DMG criteria][DMG] — install-path policy
- [ARCH-0011 cmux as agent overlay on libghostty][CMUX] — agent-team sessions whose transcripts this captures
- [ARCH-0006 Commit signing][SIGNING] — global signing policy that checkpoint commits inherit

[ENTIRE]: https://github.com/entireio/cli
[ENTIRESEC]: https://docs.entire.io/security
[ENTIRECFG]: https://docs.entire.io/cli/configuration
[MEMENTO]: https://github.com/mandel-macaque/memento
[GITAI]: https://github.com/git-ai-project/git-ai
[JOURNAL]: ARCH-0026 Cross-session journaling bridge.md
[DMG]: ARCH-0014 Brewfile vs manual DMG criteria.md
[CMUX]: ARCH-0011 cmux as agent overlay on libghostty.md
[SIGNING]: ARCH-0006 Commit signing.md
