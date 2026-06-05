---
title: OpenPGP v6 and post-quantum schism
description: Two specs claim OpenPGP's succession. GnuPG rejects RFC 9580 v6 and ships LibrePGP post-quantum on v4/v5 packets with its own codepoints; the IETF draft that Proton and Sequoia implement puts post-quantum on v6 with different codepoints. Wire-incompatible on both axes, and structurally so. Policy - v6 and post-quantum certificates are foreign objects to a GnuPG stack: never imported, never a root of identity, archived together with a pinned v6-capable decryptor. Identity keys stay v4 classical, the interop intersection.
type: adr
category: security
tags:
    - gpg
    - openpgp
    - v6
    - post-quantum
    - librepgp
    - interop
status: accepted
created: 2026-06-05
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0015 GPG.md"
    - "GPG-0001 GPG on YubiKey.md"
    - "GPG-0003 Post-quantum readiness.md"
    - "PROV-0010 Proton encryption and keys.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# OpenPGP v6 and post-quantum schism

## Context and Problem Statement

Two specifications now claim OpenPGP's succession, and post-quantum support rides the split:

- **RFC 9580 ("crypto-refresh", 2024)** defines v6 keys and signatures. Implemented by Sequoia-PGP, OpenPGP.js and gopenpgp (Proton's libraries), and PGPainless; RNP/Thunderbird are partway there. The IETF post-quantum draft builds on it: hybrid composites (ML-KEM-768 + X25519, ML-DSA-65 + Ed25519) that **must** be v6.
- **LibrePGP** is GnuPG's competing path. GnuPG refuses v6 packets entirely — `gpg --import` rejects a v6 key as unsupported — and ships its post-quantum (Kyber, algorithm ID 29) on v4/v5 packets per its own draft.

The two disagree on **both axes at once**: key version (v6 vs v4/v5) and algorithm codepoints (105/107 vs 29). There is no common wire format. The split has hardened rather than healed — the FreePG fork of GnuPG exists precisely because upstream will not track the IETF standard. Expecting GnuPG to one day read a v6 post-quantum key means expecting it to reverse two deliberate decisions.

The practical consequence: every post-quantum certificate a managed service hands out today (Proton's exports being the common case) is a v6 IETF artifact, unreadable by any GnuPG-centered stack — now and, structurally, later. Meanwhile v4 classical keys remain the one format both worlds read and verify.

## Decision Drivers

- A GnuPG-centered stack ([GPG-0001](GPG-0001 GPG on YubiKey.md), [GPG-0005](GPG-0005 GPG toolchain on macOS.md)) keeps meeting v6 artifacts from managed services ([PROV-0010](PROV-0010 Proton encryption and keys.md)).
- Archived key material must still be readable in roughly 2030, by whatever tooling survives until then.
- An identity must verify across both worlds; rooting it in a format half the ecosystem rejects breaks verification for that half.

## Considered Options

1. **Assume GnuPG eventually reads v6 / IETF post-quantum.** Rejected: structurally unlikely — the fork happened instead of the patch.
2. **Move the daily stack to a v6-native implementation (Sequoia).** Rejected for now: the smartcard and agent flow is mature on GnuPG, and nothing daily needs v6 yet. Revisit if the ecosystem consolidates on v6.
3. **Two-world policy: GnuPG for daily classical v4; v6 and post-quantum artifacts handled only by v6-capable tools.** Chosen.

## Decision Outcome

Chosen option: **two-world policy**.

- v6 and post-quantum certificates are foreign objects to a GnuPG stack: never imported into its keyring, and never a root of identity. No subkey gets generated under a post-quantum master — every binding signature would need v6 post-quantum verification that GnuPG and the major forges cannot do, so nothing signed that way verifies.
- Any archived v6 artifact (a Proton post-quantum export, typically) is stored **together with a pinned v6-capable decryptor** — a versioned `sq` binary or gopenpgp CLI — because its future reader is the Sequoia ecosystem, not GnuPG. A backup whose only assumed reader is a tool that rejects the format is not a backup.
- Identity keys stay v4 classical Curve25519 ([GPG-0002](GPG-0002 Elliptic curve keys.md), [GPG-0003](GPG-0003 Post-quantum readiness.md)) — the intersection both worlds still read.
- [GPG-0003](GPG-0003 Post-quantum readiness.md)'s revisit triggers are read through this lens: post-quantum may reach the v6 world's stable tooling first, so the deciding event is support in the tooling that signers and verifiers actually share — possibly Sequoia or FreePG rather than GnuPG.

### Consequences

- [+] Identity stays in the interop intersection; signatures verify in both worlds.
- [+] Archives name their reader; no silent dependency on GnuPG accepting a format it rejects.
- [-] Two PGP stacks to know: `sq` enters the toolbox whenever a v6 artifact must be touched.
- [-] The schism needs watching until one world wins; any decision phrased as "when stable GnuPG supports it" must be re-read against it.

## More Information

- [A schism in the OpenPGP world (LWN)](https://lwn.net/Articles/953797/)
- [The tenth OpenPGP email summit (LWN, 2026)](https://lwn.net/Articles/1072870/) — FreePG fork, implementation status
- [RFC 9580](https://www.rfc-editor.org/rfc/rfc9580) — v6 keys and signatures
- [draft-ietf-openpgp-pqc](https://datatracker.ietf.org/doc/draft-ietf-openpgp-pqc/) — v6-only hybrid composites
- [GnuPG Kyber under LibrePGP (gnupg-devel)](https://www.mail-archive.com/gnupg-devel@gnupg.org/msg00113.html) — algorithm ID 29 on v4/v5
- [Sequoia-PGP post-quantum](https://sequoia-pgp.org/blog/2025/11/15/202511-post-quantum-cryptography/) — IETF-draft implementation
- [Proton: OpenPGP crypto-refresh](https://proton.me/blog/openpgp-crypto-refresh) — why managed-service artifacts are v6
