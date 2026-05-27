# forge-provision backlog

Forward-looking work for this Mac's provisioning. Items here are deferred,
not abandoned. Pull one into a session, do it, strike it from the list.

## GPG provisioning (ARCH-0006 follow-up)

ARCH-0006 was reframed on 2026-05-21 to make GPG-with-pinentry-mac the
preferred commit-signing path; SSH-with-FIDO2 stays as the alternative.
The provisioning side hasn't caught up — `scripts/install/` and
`scripts/configure/` only carry the SSH-FIDO2 setup. To realize the
preferred path on a fresh Mac, the next dedicated GPG session needs:

- **pinentry-mac install** — `brew "pinentry-mac"` in `manifests/Brewfile`.
- **`scripts/install/gpg-yubikey.sh`** — initialize the YubiKey OpenPGP
  applet (admin PIN, key generation or import of subkeys onto the slot).
- **`scripts/configure/gpg-signing.sh`** — writes `~/.gnupg/gpg-agent.conf`
  with `pinentry-program /opt/homebrew/bin/pinentry-mac` + cache TTLs,
  sets `git config gpg.format openpgp`, `git config user.signingkey
  <KEY-ID>!`, registers the GPG public key with GitHub.
- **dotfiles `dot_gnupg/gpg-agent.conf`** — chezmoi source for the above.
- **dotfiles `dot_gitconfig`** — flip `[gpg] format = ssh` to `openpgp`
  once provisioning is complete; today's dot_gitconfig stays on ssh.

Cross-reference: [forge-core CommitSigning skill](https://github.com/N4M3Z/forge-core/blob/main/skills/VersionControl/CommitSigning.md)
already documents both signing paths.


## Push local commits to origin

Three repos have local-only commits from the 2026-05-21 through 2026-05-26
LearnFrom + terminal-stack session. None have been pushed.

- **forge-provision** (main): ~20 commits (skills, ADRs, scripts, TLDRs,
  ARCH-0001 reframe, CLAUDE.md update, cmux TLDR). `git push origin main`.
- **forge-core** (main): ResearchTopic skill, WriteDocs skill, BuildSkill
  line-limit tighten, BehavioralSteering row. `git push origin main`.
- **forge-council** (main): ResearchCouncil skill. `git push origin main`.

## Dotfiles working-tree edits (awaiting concurrent session)

Three edits live in the dotfiles working tree but are not committed because
the concurrent dotfiles session owns the staging area (renames in flight).
Fold into a commit when that session wraps up.

- `dot_gitconfig`: `[gpg "ssh"] program` changed from
  `/opt/homebrew/bin/ssh-keygen` to `/Users/N4M3Z/.local/bin/git-ssh-sign-macos`
  (the FIDO2 wrapper).
- `dot_zshrc`: `claude()` function updated to bypass the tmux wrap when any
  args are passed (fixes `claude --resume` dropping into the wrong session).
- `dot_config/tmux/tmux.conf`: added `set-environment -g COLORTERM truecolor`
  and `set -as terminal-overrides ",*-256color:Tc"` (fixes tmux color
  degradation vs bare Ghostty/cmux). Already applied live via
  `tmux source-file`.

## Skill companion extraction (~100-line rule)

BuildSkill constraint tightened from ~150 to ~100 lines (excluding
frontmatter) on 2026-05-25. Five skills authored in this session exceed
the limit and need companion-file extraction per the ExtractPrompt skill.

| Skill            | Body lines | Over by |
| ---------------- | ---------: | ------: |
| SshToolkit       |        233 |     133 |
| GhosttyToolkit   |        214 |     114 |
| HomebrewToolkit  |        175 |      75 |
| DmgInstall       |        164 |      64 |
| TmuxToolkit      |        161 |      61 |
| Chezmoi          |        135 |      35 |

Extraction candidates per skill: pitfalls tables, config snippets, and
plugin recommendation tables move to companion files (`@Pitfalls.md`,
`@Plugins.md`, `@Config.md`). The SKILL.md keeps the summary + workflow
routing + constraints.

## tmux advanced adoption (from ResearchCouncil 2026-05-26)

High-value additions beyond the current baseline (resurrect + continuum +
catppuccin). Adopt in a dedicated tmux session.

**Adopt now (high confidence):**
- `display-popup` bindings: fzf session switcher, inline gitui, scratch shell
- [tmux-thumbs](https://github.com/fcsonline/tmux-thumbs): Rust hint-based
  copy (vimium-style letter hints on URLs/paths/hashes, prefix+Space)
- [tmux-nerd-font-window-name](https://github.com/joshmedeski/tmux-nerd-font-window-name):
  auto-rename windows to Nerd Font icons matching the running process

**Evaluate (test compatibility with cmux):**
- [sesh](https://github.com/joshmedeski/sesh) OR
  [tmux-sessionx](https://github.com/omerxx/tmux-sessionx): modern session
  manager with zoxide integration, fzf picker, git-aware naming. Pick one.
- [tmux-floax](https://github.com/omerxx/tmux-floax): persistent floating
  panes (closest tmux gets to zellij's floating panes)
- [tmux-fzf](https://github.com/sainnhe/tmux-fzf): popup command palette
  for tmux commands via fzf
- [Samoshkin nested-session pattern](https://gist.github.com/samoshkin/05e65f7f1c9b55d3fc7690b59d678734):
  F12 toggles outer tmux off for SSH-inside-tmux workflows

**Skip (superseded or low value):**
- tmux-fingers (superseded by tmux-thumbs)
- tmux-copycat (superseded by tmux-thumbs pattern matching)
- tmuxinator/tmuxp (cmux workspaces + raw scripts already cover layout)
- claude-squad (overlaps cmux workspace model + native Agent Teams)

Cross-reference: [TmuxToolkit skill](skills/TmuxToolkit/SKILL.md),
[docs/tldrs/tmux.md](docs/tldrs/tmux.md).

## zellij adoption

Plan to adopt zellij alongside tmux. The zellij feature delta that tmux
cannot match: floating panes (native, pinnable), edit-scrollback
(`Ctrl-s e` opens in `$EDITOR`), WASM plugins (sandboxed, UI-rendering),
full kitty keyboard protocol support (tmux PR #4068 was closed unmerged),
context-sensitive keybinding discoverability in the status bar.

**Blocker**: Claude Code agent teams require tmux (zellij support tracked
in upstream issues #24122 / #31901 but not shipped). Until that ships,
zellij is for non-AI-agent terminal work only.

- `brew install zellij`
- Add `brew "zellij"` to `manifests/Brewfile`
- Create `dotfiles/dot_config/zellij/config.kdl` with baseline config
- Author a ZellijToolkit skill in forge-provision (mirroring TmuxToolkit)
- Author a `docs/tldrs/zellij.md`
- Evaluate side-by-side for one week before committing to dual-stack

Cross-reference: [ARCH-0009 Terminal multiplexer tmux](docs/decisions/ARCH-0009%20Terminal%20multiplexer%20tmux.md)
(update when zellij earns a co-primary role).

## TLDRs not yet authored

- **gitui.md** — deferred from the LearnFrom session. Key content: gitui's
  one-key-per-action keybinding model (no dual-binding, no fallback),
  vim preset adoption, Ctrl+b/f page navigation.
- **ghostty.md** — referenced in GhosttyToolkit but not yet authored. The
  skill covers design + diagnostics; the TLDR would cover the day-to-day
  keybinding + reload + config-file reference.

## Deferred installs

These were vetted on 2026-05-14 and approved for inclusion, but the session
focused on dotfiles + git tooling instead. Pull into a future Brewfile pass.

- **OrbStack** (`cask "orbstack"`). Apple-Silicon native container runtime
  and Linux VM. Replaces Docker Desktop for the typical dev workflow,
  significantly lighter on RAM. Free for personal use; licensed for work.
  No container runtime is currently installed.
- **mise** (`brew "mise"`). Polyglot version manager (Node, Python, Ruby,
  Go, etc.). Coexists with the current `brew "node"` install; useful once a
  project pins a Node version that brew's bottle does not match.
- **CLI quality-of-life bundle**:
    - `brew "fd"` (find replacement, friendlier syntax)
    - `brew "bat"` (cat with syntax highlighting + paging)
    - `brew "eza"` (ls replacement, color + git status)
    - `brew "git-delta"` (git diff prettifier; configure in `~/.gitconfig`
      under `[core] pager = delta` and `[interactive] diffFilter = delta`)
    - `ripgrep` is already present (pulled in by the `rust` toolchain).

## Adoption queue

- **revdiff Claude Code plugin → AdoptArtifact**. The upstream
  [`umputun/revdiff` Claude Code plugin](https://github.com/umputun/revdiff/tree/master/.claude-plugin)
  was uninstalled from the local Claude Code marketplace on 2026-05-17 in
  favor of `tuicr` as the primary review TUI. The revdiff binary stays
  installed (`brew "umputun/apps/revdiff"`) for local-only use. The plugin
  is queued for `AdoptArtifact` adoption into forge so the skill can be
  redeployed to other CLI tools beyond Claude Code (Codex, Cursor, Aider,
  OpenCode plan-review remains wired separately via
  `scripts/configure/revdiff.sh`). Source for adoption:
  `https://github.com/umputun/revdiff/blob/master/.claude-plugin/skills/revdiff/SKILL.md`.

## Carry-over from prior journals

- **GitHub repo rename**: `gh repo rename --repo N4M3Z/dotfiles dotfiles-legacy`,
  then `gh repo create N4M3Z/dotfiles --public --source ~/Developer/N4M3Z/dotfiles --push`,
  and `gh repo create N4M3Z/forge-provision --public --source ~/Developer/N4M3Z/forge-provision --push`.
- **ARCH-0006 GPG-on-YubiKey** opt-in path. OpenPGP-based commit signing as
  a second source of trust besides the FIDO2 ed25519-sk key.
- **forge-core PR #39 follow-up**: bulk-migrate remaining skills with
  `SKILL.yaml` sidecars to inline `sources:` frontmatter.
- **OneDrive MAS install**: `brew bundle install --file=manifests/Brewfile`
  failed at a sudo prompt during the 2026-05-14 evening run. Re-run in a
  session where the admin password can be typed.
- **cmux fresh-Mac install**: handled by `scripts/install/cmux.sh`.
  Idempotent: skips if `/Applications/cmux.app` exists. Downloads from
  `https://github.com/manaflow-ai/cmux/releases/latest/download/cmux-macos.dmg`
  (canonical-latest redirect, no version pinning), mounts via `hdiutil`,
  copies the `.app` to `/Applications`, detaches, recreates the
  `~/.local/bin/cmux` CLI symlink. After install, run `cmux hooks setup`
  manually once to wire Claude Code lifecycle hooks into
  `~/.claude/settings.json`.

## Evaluate Jujutsu (jj) as git replacement

Git worktrees work for parallel AI coding sessions on Rust CLI projects (no
port conflicts, no shared state). But the underlying VCS primitives force
manual worktree lifecycle: create, rebase against main, remove, delete branch.
[Jujutsu](https://github.com/martinvonz/jj) replaces commits-and-branches
with continuous snapshotting and automatic rebasing, making worktree management
a non-issue. jj operates on a git backend so existing repos and remotes keep
working.

Evaluate:

- Install `jj` via Homebrew, add to `manifests/Brewfile`.
- Test the `jj git clone` + `jj new` + `jj squash` workflow on forge-cli.
- Confirm GitHub PR creation still works (`jj git push --change`).
- Check Claude Code compatibility (does it cope with `.jj/` instead of `.git/`?).
- If viable, update `forge-core/rules/GitWorktrees.md` to document the jj path
  alongside the worktree path.

Context: Theo Browne (t3.gg, 2026-05-26) called worktrees "an abomination"
while arguing that git itself is the wrong primitive. His T3 Code app still uses
worktrees for parallel agents, but recommends jj as the end-state replacement.
Trigger.dev separately dropped worktrees for full-stack web apps due to port and
node_modules conflicts (not applicable to forge-cli's Rust CLI).

## How items leave this list

When you do a backlog item:

1. Run the install or change.
2. Add a journal entry under `journal/<date>.md` describing what landed
   and why (the *why* is what makes the journal worth more than git log).
3. Delete the entry from this file in the same commit.
4. If the work produced a reusable script, capture it under
   `scripts/<verb>/<target>.sh` per the conventions in `CLAUDE.md`.
