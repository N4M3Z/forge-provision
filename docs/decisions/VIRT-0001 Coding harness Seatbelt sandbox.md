---
title: Coding harness Seatbelt sandbox
description: Claude Code's built-in Bash sandbox is enabled globally in auto-allow mode, realizing the harness tier of ARCH-0031 on macOS. The OS-enforced Seatbelt boundary replaces per-command permission judgment with filesystem confinement (write only in cwd, credentials unreadable via denyRead) and a hostname-allowlist network proxy. VM and Go-TLS-incompatible CLIs are excluded and run unsandboxed; strict mode is deferred until the exclusion list stabilizes.
type: adr
category: security
tags:
    - sandbox
    - seatbelt
    - claude-code
    - harness
    - credentials
status: accepted
created: 2026-06-04
updated: 2026-06-04
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0031 Workload isolation tier model.md"
    - "VIRT-0002 Linux workload isolation Apple container.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Coding harness Seatbelt sandbox

## Context and Problem Statement

The coding harness (Claude Code) executes shell commands continuously. Before this decision the only gate was the permission layer: model-mediated judgment over command strings, running in auto mode with prompts skipped. Permission rules gate the Read/Edit tools, but a Bash subprocess could still read every credential on disk; the sandbox's own default read policy likewise allows `~/.ssh` and `~/.aws/credentials` unless explicitly denied. Confidence: **established** [DOCS]. The harness tier of [ARCH-0031][31] needs an OS-enforced boundary that holds regardless of what the model chose to run, without reintroducing per-command friction.

## Decision Drivers

- The boundary must be enforced by the OS on the running process, not predicted from the command string by a model.
- Credentials must be unreadable from Bash subprocesses, closing the gap the permission layer leaves open.
- Friction must not increase: the workflow runs auto mode with prompts skipped, and the sandbox must preserve that.
- Network egress from shell commands must be allowlisted, accepting documented limits.
- VM and container management CLIs (the tooling of [VIRT-0002][V2] and the Parallels tier) must keep working.

## Considered Options

### No sandbox (permission layer only)

Status quo. Rejected: command-string judgment is bypassable and gates nothing a subprocess does after approval; credential reads from Bash were unguarded.

### Built-in sandbox in regular-permissions mode

OS boundary plus a prompt for every Bash command. Rejected: reintroduces exactly the friction auto mode was chosen to remove, while the boundary already contains what the prompt would ask about.

### Hand-rolled sandbox-exec wrappers

Custom `.sb` profiles around the harness. Rejected: the built-in sandbox ships the same Seatbelt mechanism with a maintained policy surface, a network proxy, and settings-file self-protection; a wrapper would duplicate it worse.

### Wrapping the harness in a container or VM

Stronger boundary, but the harness's daily job is editing this host's files; a VM-wrapped harness pushes every file operation across a boundary all day. Reserved for high-autonomy runs, via the [VIRT-0002][V2] tier, rather than as the default.

### Built-in sandbox in auto-allow mode (chosen)

OS-enforced Seatbelt boundary; sandboxed commands run without prompting because the boundary, not the prompt, contains them.

## Decision Outcome

Chosen: **built-in sandbox, auto-allow, configured globally in user settings** (`~/.claude/settings.json`, not this repo). The policy:

- **Filesystem**: writes confined to the working directory (sandbox default); `denyRead` over credential and key material (`~/.ssh`, `~/.aws`, `~/.azure`, `~/.gnupg`, `~/.kube`, `~/.config/gh`, `~/.config/gcloud`, `~/.git-credentials`, `~/Library/Keychains`, npm/pypi/gem/cargo credential files), matching the Trail of Bits baseline [TOB].
- **Network**: hostname allowlist covering GitHub, npm, crates.io, and Homebrew hosts, preferring specific subdomains over wildcards because the proxy decides on the client-supplied hostname without TLS inspection.
- **Exclusions**: `docker`, `gh`, `brew`, `container`, `prlctl`, `orb`/`orbctl` (plus their `rtk`-prefixed forms) run outside the sandbox. Go-based CLIs fail Seatbelt TLS verification because the sandbox blocks `trustd` IPC [TRUSTD]; VM managers spawn helpers Seatbelt denies; Homebrew also writes outside cwd.
- **Environment**: `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` strips Anthropic and cloud credentials from subprocess environments.
- **Strict mode deferred**: `allowUnsandboxedCommands` stays at its default until the exclusion list has been stable in daily use; flipping it earlier would hard-fail tools the escape hatch currently degrades gracefully.

Verified empirically on this host: writes outside cwd fail with `Operation not permitted` (kernel EPERM, not a permission prompt), cwd writes succeed, and no credential variables reach subprocesses.

### Consequences

- [+] The boundary holds regardless of model judgment: an allowed command that does more than its name suggests is still confined.
- [+] Credential files are fenced at the OS level for every Bash subprocess, with the permission layer's deny rules remaining as a second wall in front.
- [+] Prompt friction stays at auto-mode levels; the boundary replaces the question.
- [-] Each excluded command runs with no sandbox at all: the exclusion list is a hole-puncher and must stay minimal.
- [-] Exclusions match the top-level command string only: `brew install x` is excluded, but `bash script.sh` calling brew is sandboxed and fails on `/opt/homebrew` writes. Provisioning scripts that wrap excluded tools must be run directly or outside the harness.
- [-] The proxy filters hostnames without terminating TLS, so broad allowlist entries enable domain-fronting exfiltration; this residual is accepted for a dev box and bounded by keeping entries specific [DOCS].
- [-] Git over SSH does not route through the HTTP/SOCKS proxy, and excluding git does not restore it [GITSSH]; agent-driven pushes need HTTPS remotes or a per-call unsandboxed retry.

## More Information

- [ARCH-0031 Workload isolation tier model][31] — the tier this decision realizes
- [Claude Code sandboxing documentation][DOCS]
- [Anthropic engineering: sandboxing][BLOG]
- [Trail of Bits claude-code-config][TOB]

[31]: ARCH-0031%20Workload%20isolation%20tier%20model.md
[V2]: VIRT-0002%20Linux%20workload%20isolation%20Apple%20container.md
[DOCS]: https://code.claude.com/docs/en/sandboxing
[BLOG]: https://www.anthropic.com/engineering/claude-code-sandboxing
[TOB]: https://github.com/trailofbits/claude-code-config
[TRUSTD]: https://github.com/anthropics/claude-code/issues/34876
[GITSSH]: https://github.com/anthropics/claude-code/issues/10767
