---
name: HarnessSecurity
version: 0.3.0
description: "Security architecture and config provisioning for Claude Code, Codex, Antigravity, Grok, and OpenCode. Covers native sandboxes, hard denies, dcg, partial config ownership, Computer Use, and explicit capability gaps. USE WHEN provisioning or hardening an AI coding harness, configuring sandbox / permissions / auto-mode policy, wiring dcg, deciding what Computer Use may touch, or versioning config the app rewrites itself."
sources:
    - https://developers.openai.com/codex/sandbox
    - https://code.claude.com/docs/en/permissions
---

# HarnessSecurity

How the five coding harnesses on this machine are confined, and how to configure them without weakening them. This is the host-level harness layer; it pairs with [SandboxToolkit](../SandboxToolkit/SKILL.md) for untrusted or autonomous workloads.

## The layered policy model

Four layers, outermost first. Configure each harness at every layer it supports; never rely on one alone.

1. **Native sandbox (enforced where available).** Claude and Codex use macOS sandboxing; Antigravity enables its terminal sandbox; Grok selects a named sandbox profile. OpenCode has granular tool permissions but no separate kernel sandbox, so say so explicitly.
2. **Hard structural deny (enforced, unoverridable).** Claude `permissions.deny` runs before anything else; the destructive-command guard `dcg` runs as a `PreToolUse` hook on both harnesses (denials via stdout JSON on Claude, stderr + exit 2 on Codex). Regex and path rules, not model judgment. This skill covers wiring the guard; recovering from a live dcg or safety-plugin block is GuardRails' job.
3. **Soft AI-judged policy (prose).** Claude's auto-mode classifier reads the `autoMode` block (`environment`, `soft_deny`, `hard_deny`, `allow`) plus CLAUDE.md; Codex routes escalations through `approvals_reviewer` and reads AGENTS.md. Natural-language rules a classifier applies, where explicit user intent can clear a soft deny.
4. **Credential protection.** Use provider-native read denies where available. Otherwise keep credentials outside allowed project roots and disclose the gap. Authentication state is provider-owned and is never copied into tracked policy.

Prose steers (layer 3); the guard and deny rules enforce (layers 1 and 2). Never relax a lower layer to satisfy a higher one.

## The self-modification guard

An agent cannot write its own `~/.claude/settings.json` when the file carries permission or sandbox flags (`skipDangerousModePermissionPrompt`, `defaultMode`, `sandbox.excludedCommands`); the auto-mode classifier blocks the write as self-permission-widening, even when only preserving existing flags. This is intended: an agent must not edit the file that governs its own permissions.

To change harness settings, edit the dotfiles source (chezmoi `dot_claude/private_settings.json`), validate, and have the human run `chezmoi apply`. The human authorizes activation; the agent never self-grants.

## The Computer Use trust boundary

The Codex desktop app's Computer Use drives arbitrary macOS GUI apps by seeing and clicking. It runs outside the command sandbox and dcg, gated only by OS grants (Screen Recording + Accessibility, via TCC, granted by hand). It is the highest-trust capability in the stack: the `config.toml` sandbox does not constrain what it clicks. Grant it per-session for a specific task, not as a standing permission, and keep it off any autonomous path.

## Cross-harness parity

Configure the second harness to match the first where the tool allows, and make the gaps explicit rather than discovered.

| Capability | Claude | Codex | Antigravity | Grok | OpenCode |
| --- | --- | --- | --- | --- | --- |
| Workspace confinement | native sandbox | workspace-local | terminal sandbox | workspace/read-only profiles | permission rules only |
| Non-interactive review | explicit tool policy | read-only + never ask | sandbox + print mode | read-only + `dontAsk` | deny-by-default permission override |
| Credential read-deny | yes | no native equivalent | project boundary | sandbox profile | explicit path denies |
| Model pin for automation | `--model` | `--model` | `--model` | `--model` | `--model` |
| Native raw transcript | JSONL | JSONL | conversation DB | session JSONL | SQLite DB |

## Signing lanes

Who holds the key decides the lane (ARCH-0034). Each harness commits under its own identity (`<harness>@noreply.<hostname>.local`) and signs with its own passphrase-less ed25519 key at `~/.ssh/<harness>`, injected per-process by the `harness-run` overlay with `signing.behavior = "own"`; agent pushes never wait on hardware. The human's YubiKey signs only the human's own commits (batched at push, cached touch policy) and dated `signed/YYYY-MM-DD` attestation tags over reviewed history, driven by `sd sign check`/`sd sign run` on a four-hour launchd summons. Local verification runs through `~/.config/git/allowed_signers` (`scripts/configure/agent-signing.sh`); the `.local` addresses mean no GitHub Verified badge on agent commits, which is the honest state, not a gap to fake.

## App-managed config: seed, don't mirror

Harness apps rewrite their own config, injecting authentication references, plugins, trusted-hook hashes, marketplaces, and UI state. The live file churns. Manage only declared policy keys through chezmoi `modify_` templates and preserve every unknown or provider-owned field. A redacted, hash-approved plan is the durable review artifact; the live file remains provider-owned outside the declared subset.

## Constraints

- Configure every layer a harness supports; one layer alone is not the posture.
- Never weaken the sandbox, dcg, or commit signing to make a task easier; escalate to the human.
- Treat Computer Use as a deliberate, per-session grant, never autonomous.
- Change settings that govern the agent's own permissions via the dotfiles source plus a human `chezmoi apply`, never a live write by the agent.
- Never use Finder through shell or GUI automation. Computer Use is allowed only for the user's specific GUI task.
- A missing enforcement capability is a limitation, not a green check.
