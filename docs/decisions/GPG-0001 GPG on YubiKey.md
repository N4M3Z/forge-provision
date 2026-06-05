---
title: GPG on YubiKey
description: GnuPG stays in the stack for commit signing, file decryption, and OpenPGP interop, and its private keys are hardware-backed. Subkeys live on the YubiKey OpenPGP applet, the master stays offline, and every private-key operation requires the card, the PIN, and a touch. A software keyring on disk and wholesale replacement by age plus SSH signing are both rejected.
type: adr
category: security
tags:
    - gpg
    - yubikey
    - openpgp
    - hardware
    - custody
status: accepted
created: 2026-06-05
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0015 GPG.md"
    - "ARCH-0006 Commit signing.md"
    - "PROV-0003 YubiKey.md"
    - "PROV-0010 Proton encryption and keys.md"
    - "GPG-0004 OpenPGP key generation and backup.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# GPG on YubiKey

## Context and Problem Statement

Mail encryption moved to Proton ([PROV-0010](PROV-0010 Proton encryption and keys.md)) and git can sign with SSH keys, so GPG's place in the stack — and where its private keys live — needed an explicit decision rather than inertia. Three forces keep OpenPGP relevant: years of material encrypted to OpenPGP keys, correspondents and tooling that produce and verify OpenPGP signatures, and commit signing ([ARCH-0006](ARCH-0006 Commit signing.md)) where GPG is the default format.

The remaining question is custody. A software keyring on disk is readable by anything running as the user: one file copy of `~/.gnupg` plus a keylogged passphrase equals the key. The YubiKey's OpenPGP applet instead holds keys in a secure element and performs sign/decrypt/auth operations on-card — the host only ever sees a stub.

## Decision Drivers

- Private keys must never sit on a disk an attacker can read.
- Each private-key operation should require a human — PIN plus touch — so malware on the host cannot sign or decrypt silently.
- Existing OpenPGP-encrypted material must stay readable, and OpenPGP interop must keep working.
- The YubiKey is already provisioned and carried ([PROV-0003](PROV-0003 YubiKey.md)).

## Considered Options

1. **Drop GPG; let age and SSH signing replace it.** Rejected as a replacement: neither decrypts existing OpenPGP material nor produces or verifies OpenPGP signatures. They can complement GPG (new-secret encryption, alternative signing format) but not substitute for it.
2. **GPG with a software keyring on disk.** Rejected: the private keys are one file-read away from exfiltration, and nothing gates their use per operation.
3. **GPG with subkeys on the YubiKey OpenPGP applet.** Chosen.

## Decision Outcome

Chosen option: **GPG, hardware-backed on the YubiKey**.

- The sign, encrypt, and auth subkeys live on the YubiKey OpenPGP applet; the master stays offline ([GPG-0004](GPG-0004 OpenPGP key generation and backup.md)).
- The host keyring holds only public keys and stubs. Private-key operations happen on-card, gated by the PIN and a physical touch (policy in [ARCH-0006](ARCH-0006 Commit signing.md)).
- **Roles:** commit and tag signing (the default format per ARCH-0006), file decryption, OpenPGP interop.
- **Non-roles:** mail encryption (Proton, PROV-0010). New-secret encryption may adopt age/SOPS alongside without displacing GPG's compatibility role.
- Key material is elliptic ([GPG-0002](GPG-0002 Elliptic curve keys.md)) and classical for now ([GPG-0003](GPG-0003 Post-quantum readiness.md)); the toolchain comes from Homebrew ([GPG-0005](GPG-0005 GPG toolchain on macOS.md)); the master's physical backup is [GPG-0006](GPG-0006 Physical key backup.md).

### Consequences

- [+] There is no private key on the host to steal — exfiltrating `~/.gnupg` yields public keys and stubs.
- [+] Malware cannot sign or decrypt without the card present, the PIN entered, and the key touched.
- [+] Years of OpenPGP ciphertext stay readable and signature interop keeps working.
- [-] gpg-agent, scdaemon, and the CCID reader add moving parts; the reader is shared with other card uses ([PROV-0003](PROV-0003 YubiKey.md)).
- [-] Losing the card requires a second provisioned card or the offline master to recover (GPG-0004, GPG-0006).

## More Information

- [PROV-0015 GPG](PROV-0015 GPG.md) — namespace anchor and index of GPG decisions
- [ARCH-0006 Commit signing](ARCH-0006 Commit signing.md) — the signing-format decision this custody model serves
- [drDuh YubiKey-Guide](https://github.com/drduh/YubiKey-Guide) — canonical OpenPGP-on-YubiKey reference
- [Yubico: OpenPGP application](https://developers.yubico.com/PGP/) — applet capabilities and card operations
