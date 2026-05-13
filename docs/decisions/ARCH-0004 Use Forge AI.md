---
title: Use Forge AI
description: forge-core + forge-cli is the AI-instructions deployment system; install forge-cli from a prebuilt release by default
type: adr
category: architecture
tags:
    - forge
    - ai-deployment
    - install
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0001 Setup as provisioning artifacts.md"
    - "ARCH-0002 New machine provisioning order.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Use Forge AI

## Context and Problem Statement

The agentic-first machine needs agents, skills, and rules deployed into the AI tool directories (`~/.claude/`, `~/.codex/`, `~/.gemini/`, `~/.opencode/`). These artifacts can be hand-maintained, plugin-installed per provider, or deployed from a single source-of-truth. Hand-maintaining or plugin-installing forks them per provider — a change made in one place doesn't propagate. The user owns `forge-core` (source-of-truth module) and `forge-cli` (Rust binary that consumes a module and writes to each provider's directory).

Two sub-questions: (1) do we use forge for AI deployment at all, and (2) how is `forge-cli` itself installed.

## Decision Drivers

- One source-of-truth deployed to many providers, no per-provider forks
- Provider neutrality — switching or adding providers doesn't require rewriting artifacts
- Install path should be fast and toolchain-free for end-users
- The author needs an escape hatch for forge-cli HEAD

## Considered Options

For deployment system:

1. **Per-provider plugin install** — install plugins separately to each provider; no single source-of-truth; drift between providers
2. **Hand-author + copy** — manage artifacts manually in each provider directory; works once, doesn't scale
3. **forge-core + forge-cli** — single module, multi-provider deploy via a single binary

For forge-cli install:

1. **Build from source via `make install`** — requires Rust toolchain
2. **Download prebuilt release** — fast, no toolchain
3. **Homebrew tap** — would require maintaining a tap; premature
4. **Two-mode script** — release-first by default, build-from-source as a flag

## Decision Outcome

Chosen option: **forge-core + forge-cli as the deployment system, install forge-cli from prebuilt release by default**.

`scripts/install/forge.sh` downloads the latest matching-arch release from `github.com/N4M3Z/forge-cli/releases`, verifies checksum, places the binary in `~/.local/bin/`. `--from-source` flag (or `FORGE_FROM_SOURCE=1`) routes through `cd ${DEV_DIR}/forge-cli && make install` for developer machines.

`scripts/configure/forge-deploy.sh` runs `forge install --source ${DEV_DIR}/forge-core --target ${HOME}` to deploy artifacts to all four provider directories simultaneously.

This Mac initially built forge-cli from source because the script defaulted to that; the script update to release-first lands as follow-up.

### Consequences

- [+] Single source-of-truth for AI instructions across all providers
- [+] End-users skip the Rust toolchain by default
- [+] forge-cli release cadence becomes a forcing function — keep releases current
- [+] Provider neutrality — adding a new provider is a forge-core change, not a re-author
- [-] Release lag: prebuilt may trail HEAD by hours/days
- [-] Developer mode requires explicit flag on the author's own Mac

## More Information

- [N4M3Z/forge-core](https://github.com/N4M3Z/forge-core) — module source-of-truth
- [N4M3Z/forge-cli](https://github.com/N4M3Z/forge-cli) — Rust deployment binary
- [N4M3Z/forge-cli releases](https://github.com/N4M3Z/forge-cli/releases) — release artifacts
