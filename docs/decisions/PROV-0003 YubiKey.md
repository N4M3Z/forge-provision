---
title: YubiKey
description: YubiKey FIDO2 for SSH auth + signing; OpenPGP applet for optional GPG subkeys; naming convention for multiple YubiKeys
type: adr
category: tooling
tags:
    - yubikey
    - fido2
    - ssh
    - gpg
    - naming
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0006 Commit signing.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# YubiKey

## Context and Problem Statement

YubiKey is the chosen hardware token for both SSH auth + signing (via FIDO2) and OpenPGP subkeys (via the OpenPGP applet) — see [ARCH-0006](ARCH-0006 Commit signing.md) for the signing-choice context. This ADR pins down: how the YubiKey is provisioned (PINs, PUKs, management key), how multiple YubiKeys are named under `~/.ssh/` and on GitHub, and what tooling is required on macOS for FIDO2 to work end-to-end.

The author has four active YubiKeys (2× 5C Nano, 2× 5 NFC) plus a deprecated 4C. Each FIDO2 credential is hardware-bound — `ssh-keygen` generates it inside the YubiKey's secure element, the private blob never leaves the device, and credentials cannot be copied between YubiKeys. OpenPGP subkeys can be loaded onto multiple YubiKeys via offline encrypted backup of the master key.

## Decision Drivers

- Hardware-bound private keys for both SSH and GPG paths
- Predictable naming under `~/.ssh/` and on GitHub when multiple YubiKeys are live
- Tooling that works identically in interactive Terminal and non-interactive contexts (Claude Code Bash, CI)
- Follow upstream conventions (OpenSSH file naming; GPG subkey-usage flags)

## Considered Options

For SSH key filenames:

1. **OpenSSH defaults** (`id_ed25519_sk`) — fine for one key; ambiguous with multiples
2. **Role-only** (`yubikey_primary`, `yubikey_backup`) — loses physical identification
3. **Subdirectory** (`~/.ssh/keys/<name>`) — clean root but adds nesting + tool-discovery friction
4. **Model + year/context** (`yubikey_5c_nano_2026`, `yubikey_5_nfc_work`) — encodes the physical device

For FIDO middleware:

1. **Apple's `/usr/bin/ssh-keygen`** — knows the ed25519-sk algorithm but lacks the `libsk-libfido2` wrapper; fails with "provider is not an OpenSSH FIDO library"
2. **Raw `libfido2.dylib` via `SSH_SK_PROVIDER`** — wrong layer; lacks the `sk_api_version` symbol OpenSSH expects
3. **brew's `openssh`** — built with FIDO2 support; pulls `libfido2` as a dep; reachable at `/opt/homebrew/bin/ssh-keygen`

For PIN entry on signing:

1. **Default OpenSSH TTY prompt** — works interactively; hangs in non-interactive contexts
2. **`theseal/ssh-askpass`** — Mac-native Cocoa dialog via LaunchAgent; `SSH_ASKPASS` set system-wide
3. **Custom `osascript` wrapper** — minimal; no brew dep but DIY

## Decision Outcome

Chosen options: **`yubikey_<model>_<year_or_context>`** for SSH key filenames; **brew's `openssh`** invoked explicitly via `gpg.ssh.program=/opt/homebrew/bin/ssh-keygen`; **`theseal/ssh-askpass`** LaunchAgent + `SSH_ASKPASS_REQUIRE=force` in `~/.zshenv`. PIV management key: AES-192 (the firmware-5.7+ default) with "Protect with PIN" enabled — PIV is otherwise unused, so the cascade risk of PIN/PUK lockout bricking PIV slots has zero blast radius. FIDO2 application string per credential: `ssh:<github-user>`. GitHub key titles follow GPG subkey-usage convention: `<hostname> (a)` for authentication, `<hostname> (s)` for signing — same `.pub`, different `--type` on `gh ssh-key add`. The same `(s)/(e)/(a)/(c)` suffix system extends to `gh gpg-key list` entries when OpenPGP signing is opted in. Multiple YubiKeys: each gets its own FIDO2 credential (hardware-bound, separate `ssh-keygen` per device); the same OpenPGP subkeys can land on multiple YubiKeys via offline encrypted backup of the master.

| YubiKey | Filename |
| --- | --- |
| 2026 5C Nano | `yubikey_5c_nano_2026` |
| 2022 5C Nano | `yubikey_5c_nano_2022` |
| 2026 5 NFC | `yubikey_5_nfc_2026` |
| Work 5 NFC | `yubikey_5_nfc_work` |

Role (primary / backup / legacy) lives in `~/.ssh/config` `IdentityFile` ordering, not in the filename — survives demotion without rename.

### Consequences

- [+] Filename identifies the physical YubiKey unambiguously
- [+] One YubiKey covers SSH auth + signing + (opt-in) OpenPGP — no separate tokens per use
- [+] Same suffix system for SSH and GPG GitHub registrations
- [+] PIN entry works identically across interactive Terminal and non-interactive Bash subshells
- [-] Conflicts with the forge-core `NamingConventions` rule (kebab-case for non-code files); SSH key files are an upstream-OpenSSH exception — that rule needs a clarifying clause
- [-] First-time tooling chain (brew openssh + libfido2 + ssh-askpass + LaunchAgent + `SSH_ASKPASS_REQUIRE=force`) has several moving parts that must land in the right order
- [-] Remote SSH servers must run OpenSSH 8.2+ to accept FIDO2 keys (modern Linux fine)

## More Information

- [drduh/macOS-Security-and-Privacy-Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide) — endorses ed25519-sk + FIDO2 + YubiKey
- [drduh/YubiKey-Guide](https://github.com/drduh/YubiKey-Guide) — canonical OpenPGP-on-YubiKey reference for the opt-in path
- [OpenSSH FIDO2 documentation](https://man.openbsd.org/ssh-keygen) — `-t ed25519-sk`, `gpg.ssh.program`, `SSH_ASKPASS` / `SSH_ASKPASS_REQUIRE`
- [Yubico SDK: PIV PIN / PUK / management key](https://docs.yubico.com/yesdk/users-manual/application-piv/pin-puk-mgmt-key.html)
- [theseal/ssh-askpass](https://github.com/theseal/ssh-askpass) — Mac-native ssh-askpass + LaunchAgent
- forge-provision scripts: `scripts/install/ssh-yubikey-key.sh`, `scripts/configure/git-identity.sh`, `scripts/configure/git-signing-ssh.sh`
