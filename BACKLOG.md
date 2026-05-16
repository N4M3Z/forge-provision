# forge-provision backlog

Forward-looking work for this Mac's provisioning. Items here are deferred,
not abandoned. Pull one into a session, do it, strike it from the list.

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

## How items leave this list

When you do a backlog item:

1. Run the install or change.
2. Add a journal entry under `journal/<date>.md` describing what landed
   and why (the *why* is what makes the journal worth more than git log).
3. Delete the entry from this file in the same commit.
4. If the work produced a reusable script, capture it under
   `scripts/<verb>/<target>.sh` per the conventions in `CLAUDE.md`.
