---
title: GPG
description: GnuPG is part of the provisioned stack, hardware-backed on the YubiKey. GPG-specific decisions live under a dedicated GPG- ADR prefix, mirroring the VIRT- pattern, with this record as the anchor in the provisioning namespace.
type: adr
category: tooling
tags:
    - gpg
    - openpgp
    - yubikey
    - namespace
status: accepted
created: 2026-06-05
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "GPG-0001 GPG on YubiKey.md"
    - "ARCH-0006 Commit signing.md"
    - "PROV-0003 YubiKey.md"
    - "PROV-0010 Proton encryption and keys.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# GPG

## Context and Problem Statement

GnuPG remains in the stack after mail encryption moved to Proton: it signs commits and tags, decrypts existing OpenPGP material, and keeps OpenPGP interop working. Deciding it properly produced enough records — custody, curve choice, post-quantum stance, key ceremony, toolchain, physical backup — that holding them all in the PROV- namespace would crowd machine provisioning with one tool's domain. The VIRT- prefix already set the precedent for splitting a domain out.

## Considered Options

1. **Keep every GPG decision under PROV-.** Rejected: the provisioning namespace stops being navigable when one tool contributes six records.
2. **A dedicated GPG- prefix, anchored by this record.** Chosen — mirrors VIRT-.

## Decision Outcome

Chosen option: **a dedicated GPG- namespace**. GnuPG is provisioned from Homebrew and hardware-backed on the YubiKey; the decisions:

| ADR | Decision |
| --- | --- |
| [GPG-0001 GPG on YubiKey](GPG-0001 GPG on YubiKey.md) | GPG stays, hardware-backed: subkeys on the card, master offline, PIN + touch per operation |
| [GPG-0002 Elliptic curve keys](GPG-0002 Elliptic curve keys.md) | Curve25519 over RSA for all new keys |
| [GPG-0003 Post-quantum readiness](GPG-0003 Post-quantum readiness.md) | Classical on hardware; post-quantum via managed services; recorded revisit triggers |
| [GPG-0004 OpenPGP key generation and backup](GPG-0004 OpenPGP key generation and backup.md) | Offline generation, keytocard, the backup ceremony and commands |
| [GPG-0005 GPG toolchain on macOS](GPG-0005 GPG toolchain on macOS.md) | Homebrew gnupg and pinentry-mac, not GPG Suite |
| [GPG-0006 Physical key backup](GPG-0006 Physical key backup.md) | paperkey as QR plus OCR-able text, tiered media, split knowledge, restore drill |
| [GPG-0007 OpenPGP v6 and post-quantum schism](GPG-0007 OpenPGP v6 and post-quantum schism.md) | v6/post-quantum certificates are foreign objects: never imported, never identity roots, archived with a pinned v6-capable decryptor |

Adjacent decisions outside the namespace: [ARCH-0006 Commit signing](ARCH-0006 Commit signing.md) (GPG is the default signing format), [PROV-0003 YubiKey](PROV-0003 YubiKey.md) (the device and its applets), [PROV-0010 Proton encryption and keys](PROV-0010 Proton encryption and keys.md) (what GPG is deliberately not used for).

### Consequences

- [+] PROV- stays navigable; GPG decisions get room to be specific.
- [+] The index above is the one place to start reading.
- [-] One more prefix to know — this record is the cure.

## More Information

- [GPG-0001 GPG on YubiKey](GPG-0001 GPG on YubiKey.md) — start here for the foundational decision
- [GnuPG](https://gnupg.org/) — the implementation
