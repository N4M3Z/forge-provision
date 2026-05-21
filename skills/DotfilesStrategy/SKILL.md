---
name: DotfilesStrategy
version: 0.1.0
description: "Pick a dotfiles approach and reference repo. Compares chezmoi, GNU Stow, yadm, rcm, dotbot, home-manager, and bare-git on machine differentiation, templating, secrets, dependency cost, and community size. USE WHEN starting a new dotfiles repo, migrating from one manager to another, comparing dotfile tools, looking for a battle-tested dotfiles repo to copy patterns from, scoping a provisioning script that lays down configuration files, or evaluating whether to move from one approach to another."
sources:
    - https://dotfiles.github.io/
    - https://www.chezmoi.io/comparison-table/
    - https://www.gnu.org/software/stow/manual/stow.html
    - https://yadm.io/docs/overview
    - https://github.com/thoughtbot/rcm
    - https://github.com/anishathalye/dotbot
    - https://nix-community.github.io/home-manager/
    - https://www.atlassian.com/git/tutorials/dotfiles
    - https://github.com/webpro/awesome-dotfiles
---

# DotfilesStrategy

Picking a dotfiles manager is a small, consequential decision. The cost of switching later is mostly the busywork of re-laying every file, but the day-to-day ergonomics, secret handling, and multi-machine story diverge sharply between tools. Six axes drive the choice: machine differentiation, secret handling, templating, dependency cost, transparency of where files end up, and community size.

This skill compares the seven approaches in common use, recommends a default, and points at battle-tested repos worth copying patterns from.

## Workflow Routing

| Topic                                                            | Companion                           |
| ---------------------------------------------------------------- | ----------------------------------- |
| Per-tool deep-dive (mechanism, pros, cons, install, gotchas)     | [Tools.md](Tools.md)                |
| Reference repos worth studying, aggregators, online resources    | [ReferenceRepos.md](ReferenceRepos.md) |

## Decision matrix

| Situation                                                             | Best fit          |
| --------------------------------------------------------------------- | ----------------- |
| Multi-machine, secrets, templating, modest learning curve             | chezmoi           |
| Single machine, simple symlinks, want a 1993-era tool that just works | GNU Stow          |
| Want it to feel like plain git with host-specific overrides           | yadm              |
| Lightweight, Mac-centric, tag-based host config                       | rcm               |
| Comfortable with YAML, want explicit install/clean/shell hooks        | dotbot            |
| Already committed to Nix                                              | home-manager      |
| Zero dependencies, accept the foot-gun risk                           | Bare git          |

## Default recommendation

**chezmoi** is the default for any new dotfiles repo where the user has more than one machine or any secrets at all. It's a single Go binary, supports templates for per-machine variation, integrates with 1Password/Bitwarden/pass/age for secrets, and survives the typical real-world dotfiles needs (executable bits, private modes, encrypted files, run-once scripts) without requiring a second tool. Source state attributes encode metadata in filenames, eliminating sidecar config drift. See the [Chezmoi](../Chezmoi/SKILL.md) skill for mechanics.

**GNU Stow** is the right default when the user explicitly wants the absolute minimum: a tool that has been ubiquitous since 1993, does nothing but symlink farming, and has no surface area to learn beyond `stow <package>`. No templates, no secrets, no machine differentiation. Trade complexity for predictability.

**Bare git** is rarely the right default but it is the right answer when the user has zero tolerance for dependencies, accepts that `git add .` in `$HOME` would commit every file in their home folder, and uses one machine.

## When to recommend what

Match the user's situation, not theoretical purity.

1. **They already have chezmoi/stow/yadm installed and working**: don't propose a rewrite. Adopt-where-they-are unless the existing tool can't solve a real problem.
2. **They mention "Nix" or "NixOS"**: home-manager fits naturally. Suggesting anything else duplicates work.
3. **They have secrets in plaintext in their repo**: stop. Either move to chezmoi (template references to a password manager), use git-crypt as an overlay, or set up `pass`/`age` and reference encrypted blobs from whichever tool they use.
4. **They want to copy a pattern from a popular repo**: send them to [ReferenceRepos.md](ReferenceRepos.md), but warn that mathiasbynens/holman/thoughtbot are all from specific approaches; the patterns don't always transfer cleanly.

## Cross-tool concerns

Some concerns are independent of which manager is chosen:

- **Secrets**: never commit credentials, even with private repos. Use 1Password CLI, Bitwarden CLI, `pass`, `age`, or git-crypt. chezmoi, yadm, and home-manager have first-class support; stow/rcm/dotbot/bare-git require an out-of-band tool.
- **Bootstrapping a new machine**: every manager needs a one-liner that clones the repo and applies it. chezmoi's `chezmoi init --apply <github-user>` is the shortest. For stow it's typically a Makefile target. For bare-git it's documented in the [Atlassian guide][ATLASSIAN].
- **OS-specific files**: Linux and macOS share ~95% of dotfile contents but the deltas matter (Brewfile vs. apt sources, GUI app preferences). Per-machine templates (chezmoi) or alt-files (yadm, rcm, dotbot) handle this. Stow needs separate packages per OS.
- **What goes in `~/.config` vs `~/`**: prefer XDG Base Directory locations (`~/.config/<app>/`) when the app supports them. Reduces top-level clutter and makes the repo's intent clearer.

## Constraints

- Recommendations track the user's environment first. If a tool is installed and working, don't propose migration unless there's a concrete pain point.
- Don't suggest committing secrets to any repo, public or private, regardless of which tool is in use.
- For one-shot migrations between managers, prefer a manual symlink walk over scripted conversion. Edge cases (per-host overrides, executable bits, modes) tend to break mass converters.
- Star counts and "most popular" lists drift; cite the canonical hub at [dotfiles.github.io][HUB] and tool-specific docs rather than reciting numbers.

[ATLASSIAN]: https://www.atlassian.com/git/tutorials/dotfiles
[HUB]: https://dotfiles.github.io/
