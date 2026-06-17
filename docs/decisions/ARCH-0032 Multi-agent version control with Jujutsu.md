---
title: Multi-agent version control with Jujutsu
description: The version-control front-end on provisioned machines is Jujutsu (jj) run colocated over the existing git repo, adopted gradually one repo at a time and reversibly. The working copy is an auto-snapshotted commit, so there is no index for concurrent agent sessions to collide on; signing is deferred to a single batch at push (signing.behavior drop + git.sign-on-push) so the YubiKey is touched once per push rather than once per snapshot; and git tooling keeps working because colocated mode leaves a real .git/ in place. Chosen over staying on plain git with worktrees, and over non-colocated jj which would blind the git-aware toolchain.
type: adr
category: tooling
tags:
    - git
    - jujutsu
    - jj
    - vcs
    - signing
    - multi-agent
    - workflow
status: accepted
created: 2026-06-13
updated: 2026-07-06
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0006 Commit signing.md"
    - "ARCH-0028 Session persistence Entire CLI.md"
    - "ARCH-0011 cmux as agent overlay on libghostty.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Multi-agent version control with Jujutsu

## Context and Problem Statement

Git assumes one actor per working tree. The actual workflow on this machine violates that twice over: several agent sessions plus the operator share repos through [cmux](<ARCH-0011 cmux as agent overlay on libghostty.md>), and every commit is gated by a YubiKey touch ([ARCH-0006](<ARCH-0006 Commit signing.md>)). The observed failures all descend from those two facts. Staged files sit in the index for days because another session owns the staging area; commits stall on YubiKey timeouts when the touch demand arrives unattended; and the human adaptation to per-commit touch friction, batching a sitting's work into one large commit, destroys history granularity, which in turn guts staged review, session-checkpoint anchoring, and review quality. Under the squash-merge workflow the per-commit signatures on a PR branch are discarded at merge anyway, so the touches that drove the batching bought nothing durable.

The question is not "how do we tune git to hurt less" but "is git's commit-and-index model the right primitive for a multi-agent tree at all". [Jujutsu][JJ] (jj) answers no: the working copy *is* an auto-snapshotted commit, there is no staging area, change identities are stable across rewrites, and every operation is recorded in an operation log that `jj undo` / `jj op restore` can roll back. It runs on a git backend, so remotes and GitHub are unaffected.

## Decision Drivers

- Remove the shared mutable index that concurrent sessions collide on.
- Decouple signing volume from commit granularity: granular history must not cost a touch per commit.
- Keep the git-aware toolchain working: `gh`, gitui, revdiff, tuicr, the IDE, Claude Code's repo detection, and session checkpointing ([ARCH-0028](<ARCH-0028 Session persistence Entire CLI.md>)) all key off a real `.git/`.
- Reversible, low-stakes adoption: this is a trial, not a one-way migration.
- A recovery net for agent mistakes that does not depend on remembering to commit.

## Considered Options

### Stay on plain git with worktrees (status quo)

Keep git; use `git worktree` per parallel session. Rejected: it leaves the shared-index collision in place for same-tree sessions, does nothing about per-commit touch friction, and forces a manual worktree lifecycle (create, rebase, remove, delete branch/worktree) that the operator already finds heavier than the problem. Git worktrees remain the right comparison point: they are linked working trees attached to one repository, commonly created at sibling paths like `../hotfix`, and cleaned up with `git worktree remove` or `git worktree prune` when metadata is stale [GITWT].

### Jujutsu, colocated (chosen)

`jj git init --colocate` keeps `.git/` beside `.jj/`; jj imports and exports to git on every command [JJGIT]. Git tooling keeps working as an escape hatch, jj drives the model. `.jj/` is local-only and never pushed; reverting is `rm -rf .jj`, leaving the git repo intact.

### Jujutsu, non-colocated

Standard jj hides the git repo inside `.jj/repo/store/git`, with no `.git/` at the root. Rejected: it blinds every git-aware tool the workflow depends on (the review TUIs, `gh`, gitleaks, the IDE, Claude Code repo detection, session checkpointing). Remote interaction would still work, but the local cost is the entire ecosystem.

## Decision Outcome

Chosen: **Jujutsu, colocated, as the version-control front-end**, adopted gradually one repo at a time and reversibly, trialed first on forge-provision. Confidence that gradual-colocated-reversible is the right adoption shape: **established** [KLABNIK][KRYCHO].

Global config materialized by `scripts/configure/jujutsu.sh`, which reads identity and the signing key from git's own config (jj does not inherit them at runtime):

```toml
[user]
name = "<from git config user.name>"
email = "<from git config user.email>"

[signing]
behavior = "drop"
backend = "gpg"
key = "<from git config user.signingkey>"

[git]
sign-on-push = true
```

**Signing is deferred to push.** With `signing.behavior = "own"` jj would sign on every working-copy snapshot, hitting the YubiKey on nearly every command and multiplying across rebases [JJ58]. `behavior = "drop"` plus `git.sign-on-push = true` instead signs all mutable unsigned commits in a single batch immediately before pushing [JJCFG]. The gpg backend shells out to the `gpg` binary, so gpg-agent, pinentry-mac, and the card work unchanged. The result composes with the cached touch policy ([ARCH-0006](<ARCH-0006 Commit signing.md>)): a whole sitting is touch-free, and one push, however many commits it carries, costs a single touch while every pushed commit still lands "Verified" on GitHub.

**Workflow.** The squash workflow fits the commit-once-per-sitting cadence: `jj describe` names the unit of work, edits accumulate in `@` across the sitting (each command auto-snapshots, so intermediate states survive in the op log), `jj squash`/`jj split` curate the result, then `jj bookmark set main -r <rev>` and `jj git push`. After GitHub squash-merges a PR, reconcile with `jj git fetch` then `jj rebase -d main@origin --skip-emptied` [JJGH].

**Secret scanning relocates to the push boundary.** jj runs no git hooks, so the gitleaks pre-commit gate and the safety-net hook do not fire on jj-driven commits [JJGIT]. The scan moves to pre-push: `gitleaks git --log-opts "main@origin..@-"` before `jj git push`, with CI as the backstop. This is strictly no worse than today and avoids the intermediate-state leak class, since only the final described tree is pushed.

**Parallel-agent isolation is `jj workspace add`, built on demand.** Multiple agents editing one working copy still collide at the file level; `jj workspace add <path>` gives each its own working directory and `@` sharing one store [JJWC]. jj workspaces are the jj analogue to Git worktrees, but each workspace owns a separate working-copy commit and sparse patterns [JJCLI].

**Workspace placement is hygiene, not an implementation detail.** For repos under `${DEV_DIR}/N4M3Z/<repo>`, agent-created jj workspaces should live under that owning repo's local ignored `.worktrees/` directory, such as `${DEV_DIR}/N4M3Z/<repo>/.worktrees/codex-hardening`, with an explicit `--name`. Add `.worktrees/` to `.git/info/exclude` as local metadata unless the repo has a tracked policy for it. Do not create sibling garbage folders, put a jj workspace inside an unrelated repo, or use whichever cwd happened to be sandbox-writable; that confuses editors, project discovery, cleanup, and future agents reading the tree. If a harness sandbox only permits a scratch root, call that out and relocate the change into repo-local `.worktrees/` once write access is available.

**Workspace cleanup is two-step.** `jj workspace forget <name>` only stops tracking the workspace's working-copy commit; the files on disk are deleted separately [JJCLI]. If another workspace rewrites the current workspace's working-copy commit, recover the stale working copy with `jj workspace update-stale` [JJWC].

### Consequences

- [+] No shared index: the cross-session staging collisions cannot occur.
- [+] Granular history is free of touch cost; one touch per push, not per commit.
- [+] The op log (`jj undo`, `jj op restore`) recovers any operation, including a botched agent edit, without remembering to commit.
- [+] Reversible: `rm -rf .jj` returns the repo to plain git with history intact.
- [-] Colocated git sits in detached HEAD; mutations must go through jj, with raw git kept read-only, or jj and git can produce conflicting refs [JJGIT]. A discipline, recorded in CLAUDE.md, not a wall.
- [-] No git hooks fire under jj; the secret-scan relocation above is load-bearing and must be followed.
- [-] jj does not run Entire's git hooks; harmless, since transcript capture is Claude Code-driven and unaffected ([ARCH-0028](<ARCH-0028 Session persistence Entire CLI.md>)), and the linkage trailer is moot under squash-merge.
- [-] No Git LFS support; repos that depend on LFS stay on plain git for now.

## More Information

- [Jujutsu][JJ] · [config reference][JJCFG] · [git compatibility][JJGIT] · [working with GitHub][JJGH] · [working copy and workspaces][JJWC] · [workspace CLI][JJCLI]
- [Git worktree documentation][GITWT] - comparison point for linked working tree lifecycle
- [signing-on-snapshot, jj issue #58][JJ58] - why behavior=drop + sign-on-push
- [Steve Klabnik's Jujutsu tutorial][KLABNIK] · [Chris Krycho, "jj init"][KRYCHO] - adoption shape and the squash workflow
- [ARCH-0006 Commit signing](<ARCH-0006 Commit signing.md>) - signing policy the sign-on-push batch composes with
- [ARCH-0028 Session persistence Entire CLI](<ARCH-0028 Session persistence Entire CLI.md>) - checkpointing whose coexistence the trial validates
- [ARCH-0011 cmux as agent overlay on libghostty](<ARCH-0011 cmux as agent overlay on libghostty.md>) - multi-session origin of the collisions

[JJ]: https://github.com/jj-vcs/jj
[JJCFG]: https://docs.jj-vcs.dev/latest/config/
[JJGIT]: https://docs.jj-vcs.dev/latest/git-compatibility/
[JJGH]: https://docs.jj-vcs.dev/latest/github/
[JJWC]: https://docs.jj-vcs.dev/latest/working-copy/
[JJCLI]: https://docs.jj-vcs.dev/latest/cli-reference/#jj-workspace
[GITWT]: https://git-scm.com/docs/git-worktree
[JJ58]: https://github.com/jj-vcs/jj/issues/58
[KLABNIK]: https://steveklabnik.github.io/jujutsu-tutorial/
[KRYCHO]: https://v5.chriskrycho.com/essays/jj-init/
