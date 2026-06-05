---
title: Elliptic curve keys
description: New OpenPGP keys are Curve25519 — ed25519 to certify, sign, and authenticate, cv25519 to encrypt — not RSA. The curve delivers RSA-3072-class security from 256-bit keys, runs markedly faster on the card's secure element, and its rigid parameters and deterministic signatures remove whole vulnerability classes. It is the recommendation of the modern toolchain; RSA remains only for FIPS or legacy interop.
type: adr
category: security
tags:
    - gpg
    - curve25519
    - ed25519
    - rsa
    - cryptography
status: accepted
created: 2026-06-05
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "GPG-0001 GPG on YubiKey.md"
    - "GPG-0003 Post-quantum readiness.md"
    - "ARCH-0006 Commit signing.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Elliptic curve keys

## Context and Problem Statement

OpenPGP supports both RSA and elliptic-curve keys, and decade-old hardening guides default to RSA-4096. On a smartcard the choice is consequential: the secure element computes every operation, key and signature bytes ride on every signed commit, and the algorithm determines which implementation-failure classes can exist at all. YubiKey firmware has supported Curve25519 in the OpenPGP applet since 5.2.3, so the historical reason to stay on RSA is gone.

## Decision Drivers

- Security per bit on a constrained device.
- Resistance to implementation failure — side channels, bad randomness — not just mathematical strength.
- Alignment with where the toolchain and ecosystem are going, not where they were.
- Identical GitHub signature verification either way.

## Considered Options

1. **RSA-4096.** Roughly 140-bit security from 4096-bit keys; ~512-byte keys and signatures; slow to sign and very slow to generate on-card; PKCS#1 padding has a long exploit history; key generation quality depends on the RNG. Rejected for new keys.
2. **NIST P-curves (ECDSA).** Small and fast, but the curve parameters derive from unexplained seeds, classic ECDSA needs a perfect per-signature nonce (a failed RNG leaks the private key — the failure that broke real deployments), and the EUCLEAK side channel lived in an ECDSA implementation; Yubico's own mitigation advice was to use RSA or Ed25519. Rejected.
3. **Curve25519 — ed25519 for certify/sign/auth, cv25519 for encryption.** Chosen.

## Decision Outcome

Chosen option: **Curve25519**, because at this security level it is smaller, faster, and harder to misuse than RSA, and it is what the modern toolchain expects:

- **Security:** ~128-bit security from a 256-bit key — the equivalent of RSA-3072 — exceeding RSA-2048's ~112 bits, which NIST already schedules for deprecation by 2030.
- **Size:** 32-byte public keys and 64-byte signatures, an order of magnitude under RSA-4096's ~512 bytes, on every signed commit and exported key.
- **Speed:** elliptic operations are markedly faster on the secure element, exactly where RSA-4096 signing and on-card generation are slow.
- **Design:** the curve constants are rigid — the smallest values meeting stated criteria, leaving no room for hidden weaknesses — signatures are deterministic (no per-signature randomness to get wrong), and reference implementations are constant-time by construction.
- **Ecosystem:** recommended by Mozilla's OpenSSH guideline and GitHub's documentation, the default in Sequoia-PGP, GnuPG's `future-default`, and standardized for OpenPGP in RFC 9580. GitHub marks ed25519 OpenPGP signatures Verified identically to RSA.

RSA remains the right answer only under FIPS constraints (Ed25519 entered FIPS 186-5 in 2023; older validated modules lack it) or for verifiers too old to know EdDSA — neither applies here.

### Consequences

- [+] Smaller artifacts, faster card operations, and entire failure classes (padding oracles, nonce reuse, keygen-RNG weakness) removed by construction.
- [+] Matches the defaults of the tools this stack already uses.
- [-] Pre-5.2.3 YubiKeys and GnuPG older than 2.1 cannot use the key — irrelevant on current hardware.
- [-] A FIPS-regulated environment would require RSA-3072+ or P-384 instead — not applicable here.

## More Information

- [GPG-0001 GPG on YubiKey](GPG-0001 GPG on YubiKey.md) — the custody model these keys live under
- [GPG-0003 Post-quantum readiness](GPG-0003 Post-quantum readiness.md) — why the curve is classical for now
- [SafeCurves: rigidity](https://safecurves.cr.yp.to/rigid.html) — Bernstein and Lange on rigid vs manipulatable curve parameters
- [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032) (EdDSA), [RFC 7748](https://www.rfc-editor.org/rfc/rfc7748) (X25519), [RFC 9580](https://www.rfc-editor.org/rfc/rfc9580) (OpenPGP codepoints)
- [Yubico: YubiKey 5.2.3 enhancements to OpenPGP 3.4](https://developers.yubico.com/PGP/YubiKey_5.2.3_Enhancements_to_OpenPGP_3.4.html) — Curve25519 support
- [Yubico advisory YSA-2024-03](https://www.yubico.com/support/security-advisories/ysa-2024-03/) — EUCLEAK; mitigation is RSA or Ed25519
- [Mozilla OpenSSH guidelines](https://infosec.mozilla.org/guidelines/openssh) — Ed25519 preferred over RSA
- [NIST IR 8547](https://nvlpubs.nist.gov/nistpubs/ir/2024/NIST.IR.8547.ipd.pdf) — transition timelines deprecating 112-bit strength
