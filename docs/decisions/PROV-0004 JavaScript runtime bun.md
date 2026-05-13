---
title: "JavaScript runtime: bun"
description: bun is the default JavaScript runtime and global-package installer; node stays available for packages that don't yet support bun
type: adr
category: tooling
tags:
    - bun
    - javascript
    - npm
    - runtime
status: accepted
created: 2026-05-13
updated: 2026-05-13
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0007 Shell environment.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# JavaScript runtime: bun

## Context and Problem Statement

Several tools used in this provisioning are distributed via npm — `@cometix/ccline` (Claude Code statusline), and likely future global tools. node + npm is the traditional path; bun is a faster, single-binary alternative that's npm-compatible for most workflows including `bun install -g`.

## Decision Drivers

- Faster install + execution than npm
- Single static binary, no node-version-manager dance
- Drop-in `bun install -g` for global packages
- Compatibility with packages that still assume node + npm

## Considered Options

1. **node + npm only** — most compatible, slowest, classic
2. **bun only** — fastest, smallest footprint, but some npm packages still need node runtime
3. **bun-first with node available** — bun is the default; node stays installed for compat

## Decision Outcome

Chosen option: **bun-first with node available**. Brewfile entries: `brew "bun"` + `brew "node"` (node retained for compat with packages that don't yet support bun's runtime). Global tool installs use `bun install -g <pkg>`; binaries land in `~/.bun/bin/`, which needs to be on PATH. Specific application: `@cometix/ccline` installed via `bun install -g @cometix/ccline` lands at `~/.bun/bin/ccline`, referenced from `~/.claude/settings.json`'s `statusLine.command`.

### Consequences

- [+] Faster install/run than npm; less waiting on `bun install -g`
- [+] Single binary, no version-manager (nvm/fnm) needed
- [+] node fallback covers tools that depend on the node runtime specifically
- [-] Two runtimes installed — disk overhead (~150 MB combined), not a real cost
- [-] `~/.bun/bin/` must be on PATH; chezmoi-managed `.zshenv` or `.zshrc` handles this

## More Information

- [bun.sh](https://bun.sh/) — runtime + package manager
- [Bun compatibility status](https://bun.sh/docs/runtime/bun-apis) — known gaps vs node
- [@cometix/ccline](https://github.com/Haleclipse/CCometixLine) — first known consumer in this stack
