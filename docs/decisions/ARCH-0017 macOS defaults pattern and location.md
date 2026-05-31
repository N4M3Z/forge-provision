---
title: macOS defaults pattern and location
description: The macOS `defaults write` configuration follows the upstream Mathias Bynens `.macos` convention — a single bash script at `~/.macos`, deployed via chezmoi as `dot_macos`, opened with an osascript quit guard for System Settings. `scripts/configure/macos-defaults.sh` becomes a one-line wrapper that runs it.
type: adr
category: tooling
tags:
    - macos
    - defaults
    - shell
    - pattern
    - chezmoi
    - dotfiles
status: accepted
created: 2026-05-30
updated: 2026-05-30
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0005 Dotfiles engine chezmoi.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://github.com/mathiasbynens/dotfiles/blob/main/.macos
---

# macOS defaults pattern and location

## Context and Problem Statement

[mathiasbynens/.macos][BYNENS] is the genre's reference shell script of `defaults write` calls. It lives at `~/.macos`, ships as part of the user's dotfiles repo, and is run directly with `bash ~/.macos`. The convention is ~15 years old and is what every serious `.macos`-style script in the wild follows: a single bash script, a leading dot, no extension, at the user's home directory.

A `defaults` script also faces a race condition. When System Settings (or the legacy "System Preferences" app on macOS 12 and earlier) has a panel open, it caches the current preference values in memory and writes them back to the preference plists when its window closes. A `defaults write` that lands while System Settings has the same domain open can be silently reverted by the closing-window flush. Mathias's `.macos` opens with an osascript guard that quits both apps before any writes; the pattern is robust and widely adopted.

This ADR decides both the structural pattern (location, deployment, invocation) and the technique adoption (preamble guard) so the macOS defaults configuration aligns with upstream canon and survives the race condition.

## Decision Drivers

- Alignment with the upstream `.macos` canon makes the file recognizable to anyone familiar with the genre
- The defaults values are user data, not project data — they belong in the dotfiles repo, not in `forge-provision/scripts/`
- The chezmoi `dot_<name>` prefix is already in use ([ARCH-0005][5]) and naturally deploys `dot_macos` to `~/.macos`
- The osascript preamble must run before any write to prevent stale-value writeback
- The provisioning script (`scripts/configure/macos-defaults.sh`) should still exist as the orchestration entry point — `./provision.sh --topic configure` needs to find it
- Adoption is of the technique only, not of any specific preference value from upstream

## Considered Options

### Location and deployment

1. **Single file in `forge-provision/scripts/configure/macos-defaults.sh`.** Self-contained in the provisioning repo; never reaches `~/.macos`. Diverges from the upstream convention.
2. **Single file at `~/.macos` deployed via chezmoi as `dot_macos`.** Matches the upstream convention exactly. The provisioning repo references it via a wrapper.
3. **Two-file split (content + orchestration).** Non-canonical. Content at `~/.macos`, dry-run and verify-by-read wrapping in `scripts/configure/macos-defaults.sh`. More moving parts; no upstream precedent.

### Race-condition handling

A. **No guard.** Require the user to close System Settings before running. Documentation burden.
B. **Detect-and-abort.** Exit with error if System Settings is running. Friction.
C. **`osascript` quit preamble.** Quit System Settings (and System Preferences) silently before any writes. No-op when neither is running.

## Decision Outcome

Chosen options: **2 + C**.

- Canonical location: `~/.macos`. Deployed by chezmoi as `dot_macos` in the dotfiles repo.
- `scripts/configure/macos-defaults.sh` becomes a one-line wrapper that delegates to `~/.macos`:

    ```sh
    #!/bin/bash
    # Delegate to the canonical .macos script deployed by chezmoi.
    # See ARCH-0017 for the rationale.
    exec bash "$HOME/.macos"
    ```

- `~/.macos` opens with the preamble guard before any writes:

    ```sh
    osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
    osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
    ```

- The provisioning orchestrator (`./provision.sh --topic configure`) discovers `scripts/configure/macos-defaults.sh` and runs it; the wrapper finds `~/.macos`; the upstream-canonical script runs.

### What is adopted from upstream and what is not

- **Adopted**: the filename and path (`~/.macos`), the preamble guard pattern, sectioned `defaults write` blocks, `killall <process>` to reload affected components, the discipline of breadth across domain coverage.
- **Not adopted**: the specific preference values. The upstream `.macos` reflects one developer's preferences from a snapshot of macOS in some past year. The local `~/.macos` captures what this specific Mac actually has configured (verified via `defaults read`) and pins those.

The distinction is load-bearing. Copy-pasting `.macos` wholesale would impose another developer's preferences without justification. Copy-pasting the structural pattern imposes a defensive technique that is robust regardless of what writes follow.

### Migration

The current `scripts/configure/macos-defaults.sh` contains both the orchestration and the content. The migration is:

1. Move the body of the existing script (everything after the `set_and_show` helper) into a new dotfiles source file `dot_macos`.
2. Reduce `scripts/configure/macos-defaults.sh` to the wrapper shown above.
3. Verify `chezmoi apply` lands `~/.macos` correctly.
4. Verify `./scripts/configure/macos-defaults.sh` still runs end-to-end and is idempotent.

The migration is queued in `BACKLOG.md`; the ADR's convention is accepted now.

### Consequences

- [+] The configuration file is at the canonical `~/.macos` location, recognizable to anyone familiar with the genre
- [+] Defaults values live in the dotfiles repo where they belong; provisioning script stays an entry point only
- [+] Writes survive on machines where System Settings was left open in the background
- [+] The technique-vs-content distinction generalizes: future technique adoptions (sectioning, killall order, verify-by-read) are allowed; future content adoptions (preference values) require justification per-key
- [+] The wrapper at `scripts/configure/macos-defaults.sh` keeps `./provision.sh --topic configure` working without a special case
- [-] Two files instead of one (wrapper + content), with a small ownership-boundary cost
- [-] The configuration is only present on the host after `chezmoi apply` runs — running the wrapper before chezmoi has deployed `dot_macos` fails
- [-] Silently closing System Settings can surprise a user who had a panel open for unrelated reasons
- [-] The osascript dependency is implicit — Apple ships it but a hardened-macOS profile that removes AppleScript would break the guard

## More Information

- [mathiasbynens/.macos][BYNENS] — upstream reference script
- [ARCH-0005 Dotfiles engine chezmoi][5] — the deployment mechanism for `dot_macos`
- [`scripts/configure/macos-defaults.sh`][SCRIPT] — the wrapper that delegates to `~/.macos`

[BYNENS]: https://github.com/mathiasbynens/dotfiles/blob/main/.macos
[5]: ARCH-0005%20Dotfiles%20engine%20chezmoi.md
[SCRIPT]: ../../scripts/configure/macos-defaults.sh
