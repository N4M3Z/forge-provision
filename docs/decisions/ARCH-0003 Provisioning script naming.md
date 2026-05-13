---
title: Provisioning script naming
description: Scripts under scripts/ are organized as verb-at-directory, noun-at-filename
type: adr
category: architecture
tags:
    - conventions
    - filesystem-layout
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0001 Setup as provisioning artifacts.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Provisioning script naming

## Context and Problem Statement

`scripts/` grows as provisioning evolves. Without a convention, files pile up flat or get grouped inconsistently. An agent reading the directory should infer the layout immediately — predictable placement matters more than expressive filenames.

## Decision Drivers

- New script placement is mechanical, not subjective
- The directory itself documents the provisioning surface
- Mirrors `check-mac`'s flat-in-topic convention
- The orchestrator owns execution order, not the filesystem

## Considered Options

1. **Numbered prefixes** (`01-xcode-cli.sh`) — encodes order in the filesystem, but order belongs to the orchestrator
2. **Flat single directory** — scales poorly past ~10 scripts
3. **Topic-based subdirs** (`bootstrap/`, `claude/`, `system/`) — categorization is arbitrary
4. **Verb at directory, noun at filename** (`install/brew.sh`, `migrate/claude-history.sh`) — action shapes the dir, target shapes the file

## Decision Outcome

Chosen option: **verb dir, noun file**. Flat within each verb dir — no numbered prefixes, no further nesting. The orchestrator `provision.sh` owns execution order.

| Verb         | Purpose                              | Examples                                                                    |
| ------------ | ------------------------------------ | --------------------------------------------------------------------------- |
| `install/`   | Install software                     | `xcode-cli.sh`, `brew.sh`, `claude-code.sh`, `forge.sh`, `terminal-theme.sh` |
| `clone/`     | Clone reference repos                | `references.sh`                                                             |
| `migrate/`   | Migrate data from an old machine     | `claude-history.sh`, `claude-instructions.sh`                               |
| `configure/` | Apply settings / config              | `macos-defaults.sh`, `claude-settings.sh`, `forge-deploy.sh`                |
| `verify/`    | Post-conditions / health checks      | (future — likely a `check-mac` wrapper)                                     |

### Consequences

- [+] Placement is mechanical: identify verb, name target
- [+] `ls scripts/<verb>/` is a complete surface for that action
- [+] Mirrors `check-mac`'s flat-in-topic-dirs pattern
- [-] Edge cases require judgment (e.g. `install/terminal-theme.sh` is more configure than install — resolved by primary mutation)

## More Information

- `N4M3Z/check-mac` — sibling repo convention this borrows from
