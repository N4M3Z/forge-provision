---
title: GPG toolchain on macOS
description: GPG comes from Homebrew (gnupg plus pinentry-mac), not the GPG Suite / GPGTools bundle. The bundle ships an old GnuPG (MacGPG 2.2.x) that collides with Homebrew's current gnupg (2.5.20), its GPGMail plugin is paid and redundant now that mail encryption lives in Proton, and its GPG Keychain GUI is redundant once keys live on the YubiKey.
type: adr
category: tooling
tags:
    - gpg
    - gnupg
    - gpgtools
    - homebrew
    - macos
status: accepted
created: 2026-06-04
updated: 2026-06-04
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0006 Commit signing.md"
    - "PROV-0007 Brewfile manifest.md"
    - "PROV-0010 Proton encryption and keys.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# GPG toolchain on macOS

## Context and Problem Statement

macOS offers two ways to get GPG. The GPG Suite / GPGTools bundle packages GPGMail (an Apple Mail PGP plugin), GPG Keychain (a key-management GUI), MacGPG (their `gpg` build), and pinentry-mac. Homebrew offers `gnupg` and `pinentry-mac` as separate formulae.

The two diverge sharply in version. GPG Suite's MacGPG tracks the old GnuPG 2.2 LTS branch (MacGPG 2.2.x), while Homebrew ships current GnuPG — 2.5.20 at the time of writing. That is a full minor series and several years of releases apart. Installing the bundle for its GUI also installs MacGPG, which then collides with `brew install gnupg`: two `gpg` binaries on `PATH` sharing one `~/.gnupg`, and the bundle's path silently downgrades `gpg` to 2.2.x. The bundle's draws are GPGMail and GPG Keychain, but PGP email is being retired (mail encryption lives in Proton, [PROV-0010](PROV-0010 Proton encryption and keys.md)), and once signing keys live on the YubiKey there is little for a key-management GUI to manage.

## Decision Drivers

- One `gpg` on `PATH`, current version, scriptable for provisioning.
- No paid or redundant components.
- Avoid two `gpg` builds fighting over `~/.gnupg`.

## Considered Options

1. **GPG Suite / GPGTools bundle.** Rejected: ships MacGPG 2.2.x (a minor series behind Homebrew's 2.5.x), GPGMail is paid and redundant now that Proton handles encrypted mail, GPG Keychain is redundant once keys are on the card, and MacGPG conflicts with Homebrew's `gnupg`.
2. **Homebrew `gnupg` plus `pinentry-mac`.** Chosen.

## Decision Outcome

Chosen option: **the Homebrew lane**.

- Install `gnupg`, `pinentry-mac`, and `ykman` from Homebrew.
- Do not install GPG Suite, GPGMail, or GPG Keychain.
- `pinentry-mac` is still the right pinentry; it is a standalone Homebrew formula and does not require the bundle.

### Consequences

- [+] Current GnuPG (2.5.20), one `gpg` on `PATH`, fully scriptable.
- [+] No paid GPGMail, no redundant GUI, no 2.2-vs-2.5 dual-`gpg` conflict.
- [-] No GPG Keychain GUI key browser — rarely needed; `ykman` plus `gpg --card-edit` cover the YubiKey and the `gpg` CLI covers the rest.
- [-] Apple Mail loses PGP — intended, since PGP email is retired and Proton is the encrypted-mail path.

## More Information

- [ARCH-0006 Commit signing](ARCH-0006 Commit signing.md) — uses `gnupg` and `pinentry-mac` from this toolchain
- [PROV-0007 Brewfile manifest](PROV-0007 Brewfile manifest.md) — where these formulae are pinned
- [PROV-0010 Proton encryption and keys](PROV-0010 Proton encryption and keys.md) — why mail encryption no longer needs GPGMail
- [GPG Suite / GPGTools](https://gpgtools.org/) — the bundle that is not used
- [GPGTools/MacGPG2](https://github.com/GPGTools/MacGPG2) — the 2.2.x branch GPG Suite ships
- [Homebrew gnupg formula](https://formulae.brew.sh/formula/gnupg) — current 2.5.x
