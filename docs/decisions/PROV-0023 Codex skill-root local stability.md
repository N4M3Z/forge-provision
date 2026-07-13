---
title: Codex skill-root local stability
description: Forge-managed Codex skills remain under ~/.codex/skills for now, despite current upstream documentation favoring ~/.agents/skills, because this machine already has forge provenance, duplicate generated roots, and a working local deployment model. Migration requires a runtime probe and byte-identical parity first.
type: adr
category: provisioning
tags:
    - codex
    - skills
    - forge-cli
    - provenance
status: accepted
created: 2026-07-06
updated: 2026-07-06
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0019 Codex as a cross-reference coding agent.md"
    - "ARCH-0004 Use Forge AI.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://developers.openai.com/codex/skills
---

# Codex skill-root local stability

## Context and Problem Statement

Current Codex documentation describes `.agents/skills` as the shared skill root,
while this machine already has forge-deployed Codex skills under `.codex/skills`
plus a duplicate `.agents/skills` tree from earlier convergence work. The two
roots overlap heavily, and some same-named skills differ.

Blindly switching forge deployment to `.agents/skills` would change the live
daily-driver environment, interact with forge manifests and provenance, and
make it hard to tell which root Codex actually loaded in this build. The
migration needs a measured safety check, not a path rename.

## Decision Drivers

- Preserve a working local Codex setup during daily-driver hardening.
- Avoid deleting generated content until byte-identical parity is proven.
- Keep forge provenance and manifest ownership meaningful.
- Leave room for forge-cli target maps if a future provider really needs split
  roots.

## Considered Options

1. **Move forge-managed Codex skills to `.agents/skills` now.** Matches current
   upstream documentation, but risks breaking local routing and provenance.
2. **Keep forge-managed Codex skills in `.codex/skills` for now.** Local
   stability first; use runtime probes and parity checks before any migration.
3. **Deploy to both roots.** Reduces immediate risk, but doubles ambiguity and
   makes stale skill selection harder to reason about.

## Decision Outcome

Chosen option: **option 2**, keep forge-managed Codex skills in
`.codex/skills` for now.

Before any pruning or migration:

- Run `scripts/verify/codex-skills.sh` to report duplicate names and
  byte-identical parity.
- Keep unique `.agents/skills` entries.
- Refuse to remove divergent duplicates.
- Use `scripts/configure/codex-skills-cleanup.sh --dry-run` first, then
  `--apply` only after explicit approval.

Forge-cli may support provider target maps for future routing, but the embedded
Codex default remains `.codex` in this pass.

## Consequences

- [+] The live Codex setup remains stable while hooks, policy, and config
  ownership are fixed.
- [+] Duplicate cleanup becomes reversible and evidence-based.
- [-] This intentionally diverges from the current upstream docs until the
  runtime probe proves a migration is needed.
- [-] Agents must remember that `.agents/skills` can contain useful unique
  skills even when duplicate generated entries are pruned.
