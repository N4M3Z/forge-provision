---
title: "Config home: per-user runtime in dotfiles, provisioning in forge-provision"
description: Per-user runtime configs live in the chezmoi-managed dotfiles repo. Machine-provisioning artifacts live in forge-provision. Sessions capture configs into dotfiles on touch.
type: adr
category: governance
tags:
    - dotfiles
    - provisioning
    - chezmoi
    - separation-of-concerns
status: accepted
created: 2026-05-17
updated: 2026-05-17
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0005 Dotfiles engine chezmoi.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Config home: per-user runtime in dotfiles, provisioning in forge-provision

## Context and Problem Statement

Two repos sit on every fresh Mac and both can plausibly host configuration:

- **`forge-provision`** ships a Brewfile, install scripts, configure scripts, ADRs, journals. It answers "how do I get this Mac from zero to a working state?"
- **`dotfiles`** ([ARCH-0005][ARCH-0005] adopted chezmoi as the engine) ships `dot_config/...` paths that deploy to `~/.config/<app>/...`. It answers "what should this Mac look like once it's set up?"

Without an explicit boundary, three failure modes accumulate:

1. Per-user runtime configs (a revdiff config, a gitui keymap, a `~/.gitconfig`) get edited live in `$HOME` and never make it into either repo. A fresh Mac reproduces nothing of that state.
2. App configs creep into `forge-provision/manifests/` as static files that configure scripts copy into place — bypassing chezmoi, breaking templating, and creating two homes for the same content.
3. Provisioning logic creeps into dotfiles via chezmoi `run_onchange_*` scripts that install Homebrew formulas — making dotfiles depend on package-management state that should be in `forge-provision`'s Brewfile.

The pattern needs to be explicit so each session knows where things go and how to keep the two repos in sync.

## Decision Drivers

- Clear ownership per file. Every config file should have exactly one canonical source repo.
- No drift between live `$HOME` state and tracked configs. A `chezmoi apply` on a fresh Mac (after `brew bundle install` from `forge-provision/manifests/Brewfile`) should reproduce the original.
- Configure scripts and chezmoi must agree. When both could write to the same target (e.g., `~/.gitconfig`), the dotfile is the canonical source and the script transitions toward redundancy.
- Reproducibility on a fresh machine. The cost of forgetting to capture a config compounds with every machine setup.

## Considered Options

1. **Everything in dotfiles via chezmoi.** Brewfile becomes a chezmoi-deployed file; `run_onchange` scripts install formulas. Provisioning concerns absorbed into dotfiles.
2. **Everything in forge-provision as static manifests.** Configs live under `manifests/<app>/`; configure scripts copy them into `~/.config/<app>/`. No chezmoi involvement.
3. **Split by concern (chosen).** Per-user runtime configs in dotfiles (chezmoi-managed); provisioning artifacts in forge-provision (Brewfile, install scripts, configure scripts).

## Decision Outcome

Chosen option: **split by concern.** Configs that answer *"what should my machine look like once it's set up?"* live in `~/Developer/N4M3Z/dotfiles` and deploy via `chezmoi apply`. Configs that answer *"how do I get a fresh machine to that state?"* live in `~/Developer/N4M3Z/forge-provision` and apply via `brew bundle install` + the appropriate `scripts/<verb>/<target>.sh`.

Both repos coordinate. `scripts/configure/<tool>.sh` may run `chezmoi apply` to deploy a dotfile, but the canonical source of the deployed content lives in dotfiles, not in `manifests/`. Where a configure script writes the same content a dotfile could provide (e.g., `git-identity.sh` setting `user.name`), both can coexist with identical values; the dotfile is the source of truth and the script becomes redundant over time.

**Capture obligation.** Any session that modifies a per-user runtime config in `$HOME` must bring that config into dotfiles within the same session — not the next session, not "later." Deferring is the failure mode this ADR exists to prevent. The pattern is: edit the chezmoi source (`dotfiles/dot_<path>`), run `chezmoi apply` to deploy, verify against the live file.

The rule lives at [`rules/DotfilesScope.md`][SCOPE] and is enforced per-session by the AI agent reading the rule (forge rules are always loaded).

Status: accepted, in force as of 2026-05-17.

### Consequences

- [+] Each config file has one canonical home; the boundary test ("what is set" vs "how to set it") routes new content unambiguously.
- [+] A fresh Mac is reproducible with two commands: `brew bundle install --file=manifests/Brewfile` then `chezmoi apply`.
- [+] Sessions that touch `~/.config/<app>/...` are forced to capture into dotfiles immediately, preventing the slow drift that accumulates across machines.
- [-] Two repos to commit to — touching a config and its install script in the same session means commits in both `dotfiles` and `forge-provision`.
- [-] Transitional redundancy where a configure script and a chezmoi-managed dotfile both write to the same target (`~/.gitconfig` is the current example). Both write identical values, so the redundancy is harmless until the configure script is retired.
- [-] Sensitive configs (the kind containing API keys, e.g., `~/.config/opencode/opencode.json`) need a third strategy beyond plain `dot_*` — `private_dot_*` paths with chezmoi templating from a secret manager, or git-crypt overlay. Out of scope for this ADR; revisit when adding secret-bearing configs.

## More Information

- [`rules/DotfilesScope.md`][SCOPE] — the always-loaded rule that enforces the boundary in every session.
- [ARCH-0005][ARCH-0005] — chose chezmoi as the engine; this ADR builds on that by scoping its content domain.
- [mathiasbynens/.macos](https://github.com/mathiasbynens/dotfiles/blob/main/.macos) — the genre-reference shell script for macOS defaults provisioning. Sits in forge-provision (where it morally belongs), not dotfiles.

[ARCH-0005]: ARCH-0005%20Dotfiles%20engine%20chezmoi.md
[SCOPE]: ../../rules/DotfilesScope.md
