---
title: Proton encryption and keys
description: Proton's encryption is a hierarchy of per-address mail keys, an account key, and separate Drive and Pass key material, and mail is moving to post-quantum hybrid keys the YubiKey cannot hold. Given that design, Proton's keys stay in Proton: a dedicated YubiKey key handles git, Proton manages its own crypto, the YubiKey's Proton role is account 2FA, and backup is the recovery file.
type: adr
category: security
tags:
    - proton
    - keys
    - yubikey
    - backup
    - post-quantum
status: accepted
created: 2026-06-03
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0006 Commit signing.md"
    - "PROV-0003 YubiKey.md"
    - "GPG-0007 OpenPGP v6 and post-quantum schism.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Proton encryption and keys

## Context and Problem Statement

The starting idea was to reuse the ProtonMail private key as the local signing and decryption key, or to load Proton keys onto the YubiKey so mail (and maybe Drive and Pass) could be decrypted from the hardware. Deciding meant first understanding what Proton actually holds.

Proton's encryption is a hierarchy, not one key:

- **Mail** — each address has its own OpenPGP key, exportable, Curve25519, with up to 20 versions per address. Only the newest encrypts incoming mail; older versions are kept to read old mail.
- **Account key** — the root that wraps the rest. Not offered as an ordinary export; a copy reaches you only through the recovery file.
- **Drive** — a per-file and per-share key tree, every key freshly generated and anchored up to the address key. There is no key to export; Drive recovers through the account, not a key handout.
- **Pass** — a per-vault AES key wrapped by the account key. Export gives you decrypted data (JSON or CSV), never the key.

So only mail address keys leave Proton as usable keys, and the YubiKey's single OpenPGP encryption slot holds one key. On-card Proton decryption would therefore cover one address at one key version and touch nothing in Drive or Pass.

**Post-quantum changes the math.** Proton is rolling out post-quantum mail: new messages use OpenPGP v6 hybrid keys (classical X25519/Ed25519 combined with ML-KEM/ML-DSA), opt-in today, to defend against harvest-now-decrypt-later — an adversary storing your ciphertext now to decrypt once quantum computers arrive. Those hybrid keys are neither RSA nor ECC, and the YubiKey 5 cannot hold them; post-quantum on a hardware key needs new silicon. Turning on Proton's post-quantum mail therefore rules out putting the Proton key on the YubiKey regardless.

## Decision Drivers

- Keep the email identity separate from the git/dev identity — one shared key means one revocation kills both.
- The Proton key is generated on Proton's servers and never exists offline, so it makes a poor master.
- Work with the grain of Proton's design, which recovers through the account, not by handing out keys.
- Protect mail against harvest-now-decrypt-later.

## Considered Options

1. **Reuse the Proton key as the local identity.** Rejected: server-born, and couples email, commit signing, and file decryption into one key with one revocation.
2. **Put the Proton mail key on the YubiKey to decrypt mail.** Rejected: one slot covers one address at one key version, Drive and Pass are excluded, and post-quantum mail keys cannot move to the card at all.
3. **Leave Proton's keys in Proton.** Chosen.

## Decision Outcome

Chosen option: **leave Proton's keys in Proton**, because the hierarchy is built to manage and recover itself through the account, and post-quantum closes the on-card path anyway. Extracting keys to manage by hand fights that design for a thin, shrinking benefit.

- Git and local signing use a separate, dedicated key ([ARCH-0006](ARCH-0006 Commit signing.md)), never the Proton key.
- Mail, Drive, and Pass stay decrypted by Proton's own apps. Backup is the Proton recovery phrase plus recovery file, stored on offline media — not raw key export. Optionally, export the mail address keys (all versions per address) to offline media for reading old mail outside Proton.
- The YubiKey's Proton role is FIDO2 account 2FA, which protects access to Mail, Drive, and Pass at once. It uses the FIDO2 applet ([PROV-0003](PROV-0003 YubiKey.md)); no Proton decryption key goes on the card.
- Turn on Proton's post-quantum mail.

### Consequences

- [+] Email and dev identities stay separate; losing or rotating one does not cascade into the other.
- [+] A single backup, the recovery file plus phrase, covers Mail, Drive, and Pass.
- [+] Post-quantum mail protection is on.
- [-] No hardware-isolated Proton decryption — Proton's apps do it, and the offline export is the break-glass path for old mail.
- [-] Post-quantum keys close off any future Proton-key-on-YubiKey path until new hardware exists.

## More Information

- [ARCH-0006 Commit signing](ARCH-0006 Commit signing.md) — the dedicated local signing key used instead of the Proton key
- [PROV-0003 YubiKey](PROV-0003 YubiKey.md) — the FIDO2 applet that backs Proton 2FA
- [Proton key management](https://proton.me/support/pgp-key-management)
- [Proton recovery phrase and recovery file](https://proton.me/support/recovery-phrase)
- [Proton post-quantum encryption](https://proton.me/blog/introducing-post-quantum-encryption)
- [GPG-0007 OpenPGP v6 and post-quantum schism](GPG-0007 OpenPGP v6 and post-quantum schism.md) — reading an exported post-quantum key outside Proton needs v6-capable tooling, not GnuPG
