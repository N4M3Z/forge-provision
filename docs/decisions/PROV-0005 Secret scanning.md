---
title: Secret scanning
description: gitleaks (pattern-based, deterministic, --redact) for routine secret detection; local LM Studio model for deeper LLM-based analysis without sending content to cloud
type: adr
category: tooling
tags:
    - security
    - secrets
    - gitleaks
    - lm-studio
status: accepted
created: 2026-05-13
updated: 2026-05-13
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

# Secret scanning

## Context and Problem Statement

The `dotfiles-private` repo carries sensitive material — exported OpenPGP keys, Kubernetes bearer tokens, ssh host inventories with private IPs, traditional pass store contents, machine-local git tokens. Any migration of these contents to chezmoi templates, or any push to GitHub, risks leaking secrets. Need a defensive scanning layer applied to `dotfiles`, `dotfiles-private`, and forge-provision before push, and applied to anything chezmoi is about to template.

## Decision Drivers

- Deterministic detection of common secret patterns (AWS, GCP, Azure tokens, JWTs, PEM blocks, high-entropy strings)
- Output must redact matched secrets so scan reports don't themselves leak
- Deeper analysis (custom identity, hostnames, social tokens) requires LLM reasoning — but content must not leave the machine
- Must work locally on the developer's Mac; no SaaS dependency

## Considered Options

1. **gitleaks** — pattern + entropy scanner; battle-tested; `--redact` masks matches in output
2. **trufflehog** — similar; broader credential verification (actively contacts services to validate keys — undesirable for offline scanning)
3. **Custom regex** — full control but reinvents the wheel
4. **LLM-only** — flexible but slower and harder to make deterministic
5. **Cloud LLM (Claude API, OpenAI)** — risks sending secrets to a third party

## Decision Outcome

Chosen option: **gitleaks (default) + local LM Studio model for deeper analysis**. Brewfile entry: `brew "gitleaks"`. Workflow: `gitleaks detect --no-banner --redact -s <path>` against any directory tree before commits, before chezmoi `apply` of new sensitive paths, and before pushes. The `--redact` flag ensures matched secrets are masked in tool output and journal entries. For deeper LLM-based scans (subtle identity leaks, embedded hostnames, contextual patterns gitleaks doesn't recognize), route through LM Studio's local OpenAI-compatible API at `localhost:1234/v1` against whichever model the user has loaded (currently `nvidia/nemotron-3-nano-omni`); credentials live in `~/.env` (`LMSTUDIO_API_KEY`). Content never leaves the machine. Trufflehog explicitly avoided because its credential-verification mode contacts the relevant services with the candidate token, which leaks the fact of a leak even when the token is benign.

### Consequences

- [+] Deterministic baseline coverage of common secret formats; runs in seconds
- [+] Output redaction means scan reports themselves are safe to commit / share
- [+] Local LLM fallback for analysis beyond regex without third-party trust
- [+] No SaaS dependency; works offline
- [-] gitleaks default ruleset misses domain-specific secrets (custom auth schemes, internal API formats) — extendable via `.gitleaks.toml`
- [-] Local LLM is slower than cloud and requires user to spin up LM Studio with the right model loaded

## More Information

- [gitleaks](https://github.com/gitleaks/gitleaks)
- [gitleaks `--redact` flag](https://github.com/gitleaks/gitleaks#getting-started)
- [LM Studio local OpenAI-compatible API](https://lmstudio.ai/docs/local-server)
- [Feedback memory: never leak secret IPs / credentials](../../../.claude/projects/-Users-N4M3Z/memory/feedback_no_secret_leak.md) (forge-provision-external, but the policy applies)
