---
title: OpenPGP key generation and backup
description: A Curve25519 OpenPGP key (ed25519 master and sign/auth subkeys, cv25519 encryption subkey) is generated offline, the master is kept offline and backed up before keytocard, and the subkeys are moved to the YubiKey. The curve rationale is GPG-0002, the classical-not-post-quantum rationale is GPG-0003, and the backup storage policy is GPG-0006.
type: adr
category: security
tags:
    - yubikey
    - gpg
    - keytocard
    - backup
    - paperkey
    - curve25519
status: accepted
created: 2026-06-03
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0015 GPG.md"
    - "GPG-0002 Elliptic curve keys.md"
    - "GPG-0003 Post-quantum readiness.md"
    - "GPG-0006 Physical key backup.md"
    - "ARCH-0006 Commit signing.md"
    - "PROV-0003 YubiKey.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# OpenPGP key generation and backup

## Context and Problem Statement

An OpenPGP key for the YubiKey can be created two ways: generated directly on the card, or generated off the card and moved onto it with `keytocard`. The choice is governed by one hard constraint — a hardware key cannot be both non-exportable and backed up. A key born on the card never leaves it, so it has no backup; a key that can be backed up necessarily exists off the card.

That constraint resolves differently by key role. A signing key can be lost cheaply: generate a new one, register its public half, and past signatures stay verified. An encryption key cannot: losing it loses the data encrypted to it. The key here carries an encryption subkey, so recoverability is required, which rules out the no-backup option. Whatever backup exists must also keep the secret off any networked or AI tool.

## Decision Drivers

- Encryption material must be recoverable; signing material can be disposable.
- Keep the master and any secret off networked or AI tools.
- Provision a replacement or second YubiKey without re-encrypting data.
- Use modern key material the YubiKey 5 actually supports ([GPG-0002](GPG-0002 Elliptic curve keys.md)).

## Considered Options

1. **Generate everything on-card.** Non-exportable, strongest isolation, but no backup and no way to clone to a second card. Fine for a signing-only key, unacceptable for one carrying encryption.
2. **Generate on a networked machine, then keytocard.** Backup-able, but the secret touches a networked host, defeating the offline-master premise.
3. **Generate offline, keep the master offline, keytocard the subkeys (drDuh model).** Backup-able and clonable across cards; the secret exists off-card, mitigated by air-gapped generation and offline storage. Chosen.

## Decision Outcome

Chosen option: **generate offline and keytocard the subkeys**, because the encryption subkey must be recoverable and a networked machine must never see the secret.

**The key.** Curve25519 ([GPG-0002](GPG-0002 Elliptic curve keys.md)):

- ed25519 master, capability Certify only.
- ed25519 signing subkey, cv25519 encryption subkey, ed25519 authentication subkey.

The master is generated offline and kept offline; only the three subkeys move to the YubiKey via `keytocard`. A second YubiKey gets the same subkeys from the offline backup, so a lost card does not force re-encryption. Where multi-recipient encryption is used, both YubiKeys (plus an offline recipient) are listed, so a lost card needs no re-encryption either.

**Why classical, not post-quantum.** [GPG-0003](GPG-0003 Post-quantum readiness.md): no shipping YubiKey can hold a post-quantum key, and signatures do not face harvest-now-decrypt-later, so the key stays Curve25519 until post-quantum hardware and ratified tooling exist.

**Commands.** Generate in a throwaway keyring, offline:

```sh
export GNUPGHOME=$(mktemp -d)
gpg --expert --full-generate-key        # (11) ECC set-own-capabilities -> Certify only -> (1) Curve 25519
export KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')
gpg --expert --edit-key "$KEYID"        # addkey: (10) sign, (12) encrypt, (11) auth -> Curve 25519 each -> save
```

Back up before `keytocard` (it is destructive to the on-disk secret), to encrypted offline media:

```sh
export BACKUP="<encrypted-volume>/$KEYID" && mkdir -p "$BACKUP"
gpg --output "$BACKUP/key.asc"         --armor --export-secret-keys "$KEYID"
gpg --output "$BACKUP/subkeys.key.asc" --armor --export-secret-subkeys "$KEYID"
gpg --output "$BACKUP/cert.asc"        --armor --export "$KEYID"
gpg --output ~/revoke-"$KEYID".asc --gen-revoke "$KEYID"
gpg --export-secret-keys "$KEYID" | paperkey --output-type raw | base64 | qrencode -o "$BACKUP/paperkey-qr.png"
```

Move subkeys to the card and require a touch per use:

```sh
gpg --edit-key "$KEYID"                 # key 1/2/3 -> keytocard -> matching slot -> save
ykman openpgp keys set-touch sig on     # repeat for enc and aut
```

Deploy on the daily machine (touch and PIN policy: [ARCH-0006](ARCH-0006 Commit signing.md)):

```sh
unset GNUPGHOME
gpg --import "$BACKUP/cert.asc"
gpg --card-status
```

**Backup storage.** Media tiers, split knowledge, and the restore drill are [GPG-0006 Physical key backup](GPG-0006 Physical key backup.md). The invariant here: the backup is made before `keytocard`, offline, and the secret never touches a networked or AI tool.

### Consequences

- [+] Encryption data is recoverable, and a replacement card can be provisioned from the offline backup without re-encrypting.
- [+] The master never sits on a networked machine.
- [+] A lost card is survivable without re-encryption, via a second provisioned card or multi-recipient encryption.
- [-] The secret exists off-card — the unavoidable cost of recoverability — mitigated by air-gapped generation and offline storage.
- [-] The key is classical; a post-quantum signing or encryption key on hardware waits on new YubiKey silicon and stable tooling.

## More Information

- [GPG-0002 Elliptic curve keys](GPG-0002 Elliptic curve keys.md) — why the key is Curve25519
- [GPG-0003 Post-quantum readiness](GPG-0003 Post-quantum readiness.md) — why it is classical
- [GPG-0006 Physical key backup](GPG-0006 Physical key backup.md) — storage media, split knowledge, restore drill
- [ARCH-0006 Commit signing](ARCH-0006 Commit signing.md) — the signing flow this key serves
- [PROV-0003 YubiKey](PROV-0003 YubiKey.md) — device provisioning (PINs, applets, naming)
- [drDuh YubiKey-Guide](https://github.com/drduh/YubiKey-Guide) — canonical offline-master + keytocard reference
- [paperkey](https://www.jabberwocky.com/software/paperkey/) — used by the backup commands above
