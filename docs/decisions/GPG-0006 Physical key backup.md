---
title: Physical key backup
description: The offline OpenPGP master is backed up with paperkey rendered as QR codes paired with OCR-able text, on paper as the archival anchor, with encrypted USB as an annually refreshed working copy. The export keeps its passphrase, stored separately (split knowledge). Shamir sharding and the newer paper-backup tools are rejected; a restore drill gates trust in every copy.
type: adr
category: security
tags:
    - gpg
    - backup
    - paperkey
    - archival
    - qr
status: accepted
created: 2026-06-05
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0015 GPG.md"
    - "GPG-0001 GPG on YubiKey.md"
    - "GPG-0004 OpenPGP key generation and backup.md"
    - "PROV-0010 Proton encryption and keys.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Physical key backup

## Context and Problem Statement

The offline OpenPGP master ([GPG-0004](GPG-0004 OpenPGP key generation and backup.md)) needs a backup that is still restorable in 10-15 years. That horizon is governed by restore-path longevity, not tool features: a backup is only as good as the ability to decode it decades later, possibly without the original tool. Newer entrants exist — paperback (Shamir-sharded paper QR), keyfork (sharded key ceremonies), and wallet-style schemes (SLIP-39, codex32, SSKR) — so the classic paperkey approach needed a challenge before being re-adopted.

The challenge fails to displace it. paperback's v0 format is explicitly experimental with no tagged release, which disqualifies it for archival. The wallet schemes encode fixed-length 128/256-bit seeds and cannot hold a multi-kilobyte OpenPGP key at all. keyfork redesigns key provenance around a sharded ceremony rather than backing up an existing key. paperkey, by contrast, is frozen but stable (v1.6): it strips the secret to the bytes not reconstructible from the public key, adds CRC-24 checksums per line, and its output format is documented and simple enough to rebuild by hand without the tool — the strongest longevity property of any candidate.

## Decision Drivers

- Restorable in 15 years, ideally without the original tool surviving.
- Error tolerance: transcription and media damage must be detectable and recoverable.
- The secret never touches a networked or AI tool.
- One custodian — no quorum of people or places to keep intact for decades.

## Considered Options

1. **paperkey rendered as QR, paired with OCR-able text.** Frozen-but-stable tool, hand-reconstructable format, CRC-24 checksums; QR adds error correction, the text printout removes the QR-decoder dependency. Chosen.
2. **paperback.** Better engineering on paper (Shamir in GF(2^32), QR payloads), but its own README marks the format experimental and subject to breaking change. Rejected for archival.
3. **Shamir sharding (ssss, keyfork, SLIP-39, codex32, SSKR).** For a single custodian, K-of-N converts one protection problem into a harder one with symmetric failure (lose the threshold, lose the key), and the well-engineered wallet formats cannot ingest arbitrary key bytes anyway. Rejected.
4. **Metal seed plates.** Sized for 24-word wallet seeds (~100 characters), not multi-kilobyte keys. Rejected.

## Decision Outcome

Chosen option: **paperkey as QR paired with OCR-able text**, on tiered media with split knowledge and a restore drill.

- `gpg --export-secret-keys "$KEYID" | paperkey --output-type raw | base64 | qrencode -o paperkey-qr.png`, printed alongside `paperkey`'s default text output so the bytes survive even with no QR decoder at hand. The base64 wrap is load-bearing: qrencode rejects raw binary's NUL bytes, and a Curve25519 key still fits one QR base64-encoded. Restore decodes with `base64 -d` before `paperkey --pubring`.
- Volume layout: one directory per key, named by key ID, holding `key.asc` (transferable secret key), `subkeys.key.asc` (secret subkeys only), `cert.asc` (public certificate), and the paperkey pair. The revocation certificate never lands on the volume — co-located key and revocation means one theft can both use and kill the identity.
- **Paper is the archival anchor.** Consumer flash holds data for roughly one to three years unpowered, so the encrypted USB copy is a working copy, re-verified and rewritten about annually — never the long-term anchor. An M-DISC copy is an optional secondary (its reader availability in 2040 is the bet).
- **The export keeps its passphrase** — a stolen printout alone is not game-over. The passphrase is stored separately from the key material (memorized plus a sealed copy at a second location): split knowledge without Shamir's quorum fragility.
- The **public key** is stored with the backup (paperkey reconstruction requires it); the **revocation certificate** lives in a third location, separate from the key.
- **A restore drill gates trust**: on an air-gapped boot, restore from the paper copy and from each USB, confirm the fingerprint and a test sign/decrypt, before relying on the backup. Re-verify USB annually, paper every few years.

### Consequences

- [+] Every copy is restorable with commodity tools, and the paper copy even without them.
- [+] Theft of any single object (printout, USB, passphrase note) is insufficient to use the key.
- [+] No quorum of shares to keep alive for decades.
- [-] Paper and printer handling must stay offline (direct-attached printer, no spooling network device).
- [-] The annual USB refresh and periodic restore drills are recurring chores; skipping them silently erodes the guarantee.

## More Information

- [PROV-0015 GPG](PROV-0015 GPG.md) — namespace anchor and index of GPG decisions
- [GPG-0004 OpenPGP key generation and backup](GPG-0004 OpenPGP key generation and backup.md) — the ceremony that produces what this backs up
- [paperkey](https://www.jabberwocky.com/software/paperkey/) — design rationale; paper as the if-all-else-fails medium
- [drDuh YubiKey-Guide](https://github.com/drduh/YubiKey-Guide) — backup section this aligns with
- [cyphar/paperback](https://github.com/cyphar/paperback) — evaluated, rejected for its experimental format
- [za3k/qr-backup](https://github.com/za3k/qr-backup) — mature generic file-to-QR alternative if paperkey's QR path ever needs replacing
- [SLIP-0039](https://github.com/satoshilabs/slips/blob/master/slip-0039.md) and [BIP-93 codex32](https://bips.dev/93/) — fixed-length seed formats, inapplicable to OpenPGP keys
