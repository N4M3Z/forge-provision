---
title: "Personal script directory with sd"
description: "Personal helper scripts move from a flat ~/.local/bin into an sd-dispatched topic tree (~/sd/<topic>/<verb>, invoked as `sd claude revive`), using a personal fork of ianthehenry/sd that adds busybox-style argv[0] symlink dispatch for callers requiring bare command names. PATH-shadowing harness shims stay outside the tree; the tree's content deploys from dotfiles, forge-provision installs the tool."
type: adr
category: tooling
tags:
    - shell
    - scripts
    - sd
    - dotfiles
status: accepted
created: 2026-07-16
updated: 2026-07-16
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0020 Zed editor-as-launcher and REPL kernels.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - "https://github.com/N4M3Z/sd"
---

# Personal script directory with sd

## Context and Problem Statement

Personal helper scripts accumulated as a flat fleet in `~/.local/bin`: dozens of chezmoi-managed shell wrappers (tmux status segments, session-name derivation, editor-open resolvers, agent revival) alongside unmanaged symlinks and hand-copied binaries. The flat namespace gives no discoverability (`ls` is the only index), invites naming collisions (`zed-run` vs `zed-open` confusion in practice), and mixes tracked scripts with untracked strays. Most of the fleet is machine-called — tmux.conf, tmux-resurrect, and editor task configs invoke scripts by name — which constrains any reorganization.

## Decision Drivers

- One discoverable, self-documenting index of the personal command fleet.
- Namespacing that ends collisions and makes ownership obvious.
- Machine callers must keep working: config-string callers can adapt, but some require bare single-word commands.
- Scripts stay editable shell (no compile loop); the tree must deploy reproducibly.

## Considered Options

1. **Status quo plus hygiene** — docstring headers and a lister over the flat directory; no structural change.
2. **Global justfile palette** — `just --list` discoverability; recipes wrap the scripts, which stay flat.
3. **Compiled personal multitool** — one Rust binary, clap multicall; strongest testing story, heaviest migration and iteration cost.
4. **sd script directory** — topic tree `~/sd/<topic>/<verb>` invoked as `sd <topic> <verb>`; help from script comments; scripts stay plain executables.

## Decision Outcome

Chosen option: **sd**, via the personal fork ([N4M3Z/sd](https://github.com/N4M3Z/sd)) that adds multicall symlink dispatch (`tmux-battery -> sd` resolves to `~/sd/tmux/battery` by joining path components with `-`). The namespaced invocation (`sd claude revive`, `sd tmux battery`) is the preferred form everywhere a caller accepts a command string — tmux.conf resurrect and status segments, editor task and init commands — and the multicall symlink is the escape hatch for callers that require a bare name. PATH-shadowing harness shims (`claude`, `codex`, and peers) stay outside the tree: they work by intercepting real binary names, and a bare `claude` multicall name would collide with the `~/sd/claude/` topic directory. Ownership split follows the dotfiles boundary: forge-provision installs the tool (`scripts/install/sd.sh`: clone the fork, symlink `sd` and the `_sd` completion) and records this decision; the script tree itself is per-user runtime content and deploys from the dotfiles repo.

### Consequences

- [+] `sd <topic>` lists each family with help text pulled from existing header comments; the flat-namespace collision class ends.
- [+] Machine callers migrate incrementally: config strings switch to `sd …` invocations, bare-name requirements get a symlink, nothing breaks mid-migration.
- [+] Scripts remain plain editable shell with the same chezmoi capture loop.
- [-] The fork must track upstream (dormant since 2022, so drift risk is low) and the multicall patch is unmerged upstream.
- [-] Two-level invocation (`sd tmux battery`) is longer to type interactively than a bare name; completions mitigate.
- [-] Unmanaged third-party binaries in `~/.local/bin` are out of scope here and still need a manifest answer.

## More Information

- Fork and feature: [N4M3Z/sd](https://github.com/N4M3Z/sd), branch `multicall`.
- Upstream: [ianthehenry/sd](https://github.com/ianthehenry/sd) and its design post.
- The Zed launcher tasks that consume these scripts: PROV-0020.
