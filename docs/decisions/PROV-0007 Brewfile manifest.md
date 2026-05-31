---
title: Brewfile manifest
description: Two manifests using the standard Homebrew Bundle DSL — manifests/Brewfile is the daily-driver baseline, manifests/Brewfile.optional is the evaluation set. Filename split is our convention; the format is upstream.
type: adr
category: tooling
tags:
    - homebrew
    - brewfile
    - homebrew-bundle
    - lifecycle
    - evaluation
status: accepted
created: 2026-05-30
updated: 2026-05-30
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0014 Brewfile vs manual DMG criteria.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://docs.brew.sh/Manpage#bundle-subcommand
    - https://github.com/Homebrew/homebrew-bundle
---

# Brewfile manifest

## Context and Problem Statement

Homebrew's [`brew bundle`][BUNDLE] subcommand reads a Ruby-DSL manifest (default filename `Brewfile`) with `brew`, `cask`, `tap`, `mas`, and `vscode` directives. `brew bundle install` reconciles the running system to the manifest. The Brewfile format and the bundle subcommand are upstream Homebrew, not project-local — what's project-local is which file gets used and how many.

A working Mac accumulates evaluation installs: apps tried, kept around for comparison, but never adopted into the daily workflow. Examples on this machine: Warp (overlaps with Claude Code's AI features), Wave Terminal (Electron + React, useful for graphical blocks but heavy for daily driving). Two failure modes if these live in the main `manifests/Brewfile`:

- A fresh Mac wastes time and disk installing evaluation cruft that the user no longer reaches for.
- The signal of "this is the baseline" gets diluted — readers cannot distinguish "I depend on this" from "I tried this once."

[ARCH-0014][14] covers cask-vs-DMG choice for a single app's lifecycle. It does not cover the multi-manifest question: where do evaluation apps live, and when do they graduate or get pruned?

## Decision Drivers

- A fresh-Mac install should reproduce only what the user actually relies on
- Evaluation apps should be declared (so they survive across machines for comparison) but not bundled into the baseline
- The graduation path (optional → main) and pruning path (optional → uninstall) should be explicit
- The mechanism must use vanilla Homebrew Bundle — no custom tooling
- `brew bundle install --file=manifests/Brewfile.optional` should remain a one-command opt-in

## Considered Options

1. **All apps in the standard `Brewfile`.** Simple, single manifest. Conflates baseline and evaluation; pollutes fresh-Mac installs.
2. **Evaluation apps uninstalled until re-evaluated.** Cleanest baseline but loses the declared-state benefit; nothing reminds the user "you tried this in May 2026."
3. **Standard `Brewfile` plus `Brewfile.optional`.** Two manifests, same Homebrew Bundle DSL, distinguished by filename. The `--file=<path>` flag is built into `brew bundle`.
4. **Tags or comments in a single Brewfile.** Workable but `brew bundle install` evaluates the whole file; selecting a subset would require custom tooling.

## Decision Outcome

Chosen option: **`manifests/Brewfile` plus a sibling `manifests/Brewfile.optional`**. Both files use the upstream Homebrew Bundle DSL unchanged. The split is a filename convention, not a format extension.

- `manifests/Brewfile` is the baseline: installed by default on a fresh Mac, reproduces the user's actual daily workflow.
- `manifests/Brewfile.optional` is the evaluation set: installed deliberately with `brew bundle install --file=manifests/Brewfile.optional`. Header comment names the lifecycle role.

### Graduation: optional → main Brewfile

An entry moves from `Brewfile.optional` to `Brewfile` when:

- Daily-driver status is reached — the app is used at least weekly without conscious effort to reach for it
- No baseline app it overlaps with does the job adequately
- The user has decided to invest configuration (chezmoi sources, hotkey wiring) that's expensive to redo

When this happens, move the entry, rewrite the comment to reflect baseline rationale, and journal the graduation.

### Pruning: optional → uninstall

An entry leaves `Brewfile.optional` (and the machine) when:

- It hasn't been opened in 30+ days AND a baseline app covers the same need
- The evaluation question is settled (the verdict is captured in BACKLOG.md or an ADR if structural)
- The app's subscription tier turns out to require payment to be useful

When pruning, run `brew uninstall --cask <name>` (or `--formula`), remove the entry, and capture the verdict in BACKLOG.md or a journal entry so a future session does not re-add the app on impulse.

### Static: stays in optional indefinitely

Some apps belong in `Brewfile.optional` permanently because their reason for existing is comparison or fallback, not daily use. Example: a second terminal kept around for "is my issue Ghostty-specific?" debugging. The comment should say so explicitly.

### Consequences

- [+] Fresh Mac install reproduces the actual baseline, not evaluation cruft
- [+] Evaluation apps stay declared and reproducible across machines without polluting the baseline
- [+] The optional file becomes a record of what was tried — entries are historical signal even when uninstalled later
- [+] Composes cleanly with [ARCH-0014][14] — both files can mix `cask` entries and DMG tombstones
- [+] Uses only upstream Homebrew Bundle behavior; no custom tooling, no risk of breaking when Homebrew updates
- [-] Two files to maintain and reason about; readers must know both exist
- [-] Graduation and pruning are manual judgment calls — no automation enforces the lifecycle
- [-] `brew bundle dump` produces a single Brewfile; round-tripping requires manual triage between the two files

## More Information

- [`brew bundle` subcommand manpage][BUNDLE] — upstream documentation for the standard format
- [`homebrew/homebrew-bundle`][REPO] — original tap, now merged into Homebrew core
- [ARCH-0014 Brewfile vs manual DMG criteria][14] — sibling decision on per-app install path
- [`manifests/Brewfile`][BFM] — baseline manifest
- [`manifests/Brewfile.optional`][BFO] — evaluation manifest

[14]: ARCH-0014%20Brewfile%20vs%20manual%20DMG%20criteria.md
[BUNDLE]: https://docs.brew.sh/Manpage#bundle-subcommand
[REPO]: https://github.com/Homebrew/homebrew-bundle
[BFM]: ../../manifests/Brewfile
[BFO]: ../../manifests/Brewfile.optional
