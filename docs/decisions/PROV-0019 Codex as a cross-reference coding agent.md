---
title: Codex as a cross-reference coding agent
description: OpenAI Codex runs alongside Claude Code as an independent, sandboxed cross-reviewer. The CLI (cask "codex") and desktop app (cask "codex-app") share ~/.codex/config.toml, which mirrors the Claude sandbox posture where Codex supports it (workspace-local Seatbelt permissions, a limited network domain allowlist, writable roots, the dcg guard, gbrain over MCP, a read-only review profile). denyRead and a static command-exclusion list have no Codex analog. Computer Use in the desktop app drives macOS GUIs outside that sandbox, gated only by OS permission grants.
type: adr
category: tooling
tags:
    - codex
    - claude-code
    - sandbox
    - cross-review
    - mcp
    - security
status: accepted
created: 2026-06-21
updated: 2026-07-06
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0007 Brewfile manifest.md"
    - "VIRT-0001 Coding harness Seatbelt sandbox.md"
    - "ARCH-0033 Terminal code review tooling.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Codex as a cross-reference coding agent

## Context and Problem Statement

A single agent's output is stronger when an independent agent reviews it: a competing model with full repository access catches shortcuts, unverified claims, and skipped edge cases that the author misses. Claude Code is the primary agent; OpenAI Codex, a different vendor and model, is the natural second agent for that cross-reference.

The problem is provisioning Codex so it is genuinely useful as a reviewer while staying consistent with the existing security posture, the primary agent already runs its shell commands under a macOS Seatbelt sandbox ([VIRT-0001](VIRT-0001%20Coding%20harness%20Seatbelt%20sandbox.md)), behind a destructive-command guard, with credential directories denied. A second agent provisioned with weaker isolation would be the soft underbelly. The two configurations should mirror each other where the tools allow, and the gaps should be explicit rather than discovered.

## Decision Drivers

- Independent second-opinion review of the primary agent's diffs.
- Parity with the existing sandbox and guard posture, so the reviewer is not a weaker link.
- Local-first and credential-safe: the same knowledge source and the same secret protections.
- Minimal divergence: one guard, one knowledge brain, one sandbox primitive across both agents.

## Considered Options

1. **Codex CLI only.** Review via `codex exec review` in a read-only profile. Smallest footprint.
2. **Codex CLI plus the desktop app.** Adds Computer Use, which drives arbitrary macOS GUI applications.
3. **A different second agent** (Gemini, a second Claude instance). Avoids a new vendor but loses the value of genuine model diversity in review.

## Decision Outcome

Chosen option: **option 2**, both the Codex CLI and the desktop app, configured to mirror the Claude sandbox posture wherever Codex supports it.

- **Install.** `cask "codex"` (CLI, Homebrew-pinned) and `cask "codex-app"` (desktop, self-updating). Authentication is interactive (`codex login`). `~/.codex/config.toml` is seeded from a curated baseline by `scripts/configure/codex.sh`; the desktop app then manages the live file.
- **Sandbox parity.** `default_permissions = "workspace-local"` uses the same Seatbelt primitive as Claude; `approval_policy = "on-request"` and `approvals_reviewer = "auto_review"` approximate Claude's auto-mode classification path. The `[permissions.workspace-local.network]` domain allowlist mirrors Claude's `sandbox.network.allowedDomains`; `workspace_roots` mirrors `allowWrite`; `[shell_environment_policy]` mirrors the subprocess env scrub. The destructive-command guard runs as a `PreToolUse` hook, the same guard the primary agent uses.
- **Cross-reference role.** A read-only `[profiles.review]` (`approval_policy = "never"`, `sandbox_mode = "read-only"`) so the reviewer cannot edit and cannot prompt: it fails closed instead of "fixing" a disagreement and masking it.
- **Knowledge.** The local knowledge brain is wired as an MCP server in the personal config layer.
- **What does not translate.** Codex has no read-deny (Seatbelt reads stay broad, so credential directories are not read-blocked the way Claude's `denyRead` does it) and no static command-exclusion list (commands that need denied network or system access escalate through `approval_policy` rather than running unsandboxed; the built-in execpolicy is not user-authored).
- **Policy specification across both agents.** Soft, AI-judged policy is expressed in prose: Claude's auto-mode classifier reads an `autoMode` block (`environment`, `soft_deny`, `hard_deny`, `allow`) plus CLAUDE.md; Codex routes escalations through `approvals_reviewer` and reads AGENTS.md. Hard policy is structural and unoverridable: `permissions.deny` and the guard's regex packs. Prose steers; the guard and deny rules enforce.
- **Config hygiene.** Keep local-model values such as `OPENAI_API_KEY = "ollama"` scoped to MCP server env blocks rather than the global shell environment. A global API-key env var makes `codex doctor` report mixed ChatGPT/API-key auth signals and can make diagnostics probe the wrong auth lane.

## Consequences

- [+] Independent cross-review runs with the same guard and knowledge source as the primary agent, so review quality does not come at the cost of a weaker security boundary.
- [+] Codex's command execution is confined by the same Seatbelt primitive and destructive-command guard as Claude's.
- [-] Computer Use (desktop) drives GUI applications outside the command sandbox and the guard; it is constrained only by the OS Screen Recording and Accessibility grants. It is the highest-trust capability in the stack and is granted deliberately, per session, not left broadly enabled.
- [-] The desktop app rewrites `~/.codex/config.toml` (plugins, trusted-hook hashes, marketplaces), so the live file is app-managed. The version-controlled artifact is the curated baseline in this module, not a mirror of the live file.
- [-] Two reviewer surfaces exist (a sandboxed CLI and an unsandboxed desktop), which must not be confused for each other.

## Links

- [Codex configuration reference](https://developers.openai.com/codex/config-reference)
- [Codex sandboxing](https://developers.openai.com/codex/sandbox)
- [Computer Use](https://developers.openai.com/codex/app/computer-use)
