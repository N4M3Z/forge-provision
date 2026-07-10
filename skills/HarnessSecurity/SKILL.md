---
name: HarnessSecurity
version: 0.1.0
description: "Security architecture and config provisioning for AI coding harnesses (Claude Code, Codex). Covers the layered model (macOS Seatbelt sandbox, hard permission-deny, the destructive-command guard, the soft auto-mode classifier), the self-modification guard, the Computer Use trust boundary, cross-harness parity, and the seed-not-mirror pattern for app-managed config. USE WHEN provisioning or hardening an AI coding harness, configuring its sandbox / permissions / auto-mode policy, wiring dcg, deciding what Computer Use may touch, mirroring config across Claude and Codex, or versioning a config file the app rewrites itself."
sources:
    - https://developers.openai.com/codex/sandbox
    - https://code.claude.com/docs/en/permissions
---

# HarnessSecurity

How the AI coding harnesses on this machine (Claude Code, Codex) are confined, and how to configure that without weakening it. This is the host-level harness layer; it pairs with [SandboxToolkit](../SandboxToolkit/SKILL.md) (the per-VM container tier) and the Seatbelt baseline (ADR VIRT-0001).

## The layered policy model

Four layers, outermost first. Configure each harness at every layer it supports; never rely on one alone.

1. **OS sandbox (enforced).** macOS Seatbelt via `sandbox-exec` confines the commands a harness runs: writes scoped to the workspace, reads broad, network off by default. Both Claude Code (the `sandbox` block) and Codex (`sandbox_mode = "workspace-write"`) use the same primitive.
2. **Hard structural deny (enforced, unoverridable).** Claude `permissions.deny` runs before anything else; the destructive-command guard `dcg` runs as a `PreToolUse` hook on both harnesses (denials via stdout JSON on Claude, stderr + exit 2 on Codex). Regex and path rules, not model judgment. This skill covers wiring the guard; recovering from a live dcg or safety-plugin block is GuardRails' job.
3. **Soft AI-judged policy (prose).** Claude's auto-mode classifier reads the `autoMode` block (`environment`, `soft_deny`, `hard_deny`, `allow`) plus CLAUDE.md; Codex routes escalations through `approvals_reviewer` and reads AGENTS.md. Natural-language rules a classifier applies, where explicit user intent can clear a soft deny.
4. **Credential protection.** Claude `sandbox.filesystem.denyRead` read-blocks credential directories; Codex has no read-deny (Seatbelt reads stay broad), so credential isolation there rests on the OS account, not config.

Prose steers (layer 3); the guard and deny rules enforce (layers 1 and 2). Never relax a lower layer to satisfy a higher one.

## The self-modification guard

An agent cannot write its own `~/.claude/settings.json` when the file carries permission or sandbox flags (`skipDangerousModePermissionPrompt`, `defaultMode`, `sandbox.excludedCommands`); the auto-mode classifier blocks the write as self-permission-widening, even when only preserving existing flags. This is intended: an agent must not edit the file that governs its own permissions.

To change harness settings, edit the dotfiles source (chezmoi `dot_claude/private_settings.json`), validate, and have the human run `chezmoi apply`. The human authorizes activation; the agent never self-grants.

## The Computer Use trust boundary

The Codex desktop app's Computer Use drives arbitrary macOS GUI apps by seeing and clicking. It runs outside the command sandbox and dcg, gated only by OS grants (Screen Recording + Accessibility, via TCC, granted by hand). It is the highest-trust capability in the stack: the `config.toml` sandbox does not constrain what it clicks. Grant it per-session for a specific task, not as a standing permission, and keep it off any autonomous path.

## Cross-harness parity

Configure the second harness to match the first where the tool allows, and make the gaps explicit rather than discovered.

| Capability | Claude Code | Codex | Translates? |
| --- | --- | --- | --- |
| OS sandbox | `sandbox` (Seatbelt) | `sandbox_mode` (Seatbelt) | yes, same primitive |
| Network allowlist | `network.allowedDomains` | `[features.network_proxy.domains]` | yes |
| Writable roots | `filesystem.allowWrite` | `sandbox_workspace_write.writable_roots` | yes |
| Destructive guard | dcg `PreToolUse` hook | dcg `PreToolUse` hook | yes, same tool |
| Knowledge MCP | gbrain MCP | `[mcp_servers.gbrain]` | yes |
| Read-only reviewer | no native profile | `[profiles.review]` | Codex only |
| Credential read-deny | `filesystem.denyRead` | none | no, Seatbelt reads broad |
| Command exclusion | `sandbox.excludedCommands` | none | no, escalate via approval |

## App-managed config: seed, don't mirror

Some harness apps rewrite their own config (Zed `settings.json`, the Codex desktop app's `~/.codex/config.toml`), injecting plugins, trusted-hook hashes, marketplaces, and UI state. The live file churns. Version a curated seed in this module and deploy it copy-if-absent (`scripts/configure/<tool>.sh`); never apply a full mirror over the live file, which fights the app and strips its state on the next launch. The live config belongs to the app; the seed is the durable, reviewable artifact.

## Constraints

- Configure every layer a harness supports; one layer alone is not the posture.
- Never weaken the sandbox, dcg, or commit signing to make a task easier; escalate to the human.
- Treat Computer Use as a deliberate, per-session grant, never autonomous.
- Change settings that govern the agent's own permissions via the dotfiles source plus a human `chezmoi apply`, never a live write by the agent.
