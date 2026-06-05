---
title: Post-quantum readiness
description: The hardware-resident GPG key stays classical Curve25519. Post-quantum OpenPGP is still a draft with development-branch tooling, no shipping YubiKey can hold a post-quantum key, and signatures do not face harvest-now-decrypt-later. Post-quantum protection is enabled where a managed service does the lifting — Proton mail — which also permanently rules out loading Proton keys onto the card. Revisit when post-quantum hardware and ratified tooling exist.
type: adr
category: security
tags:
    - gpg
    - post-quantum
    - pqc
    - yubikey
    - proton
status: accepted
created: 2026-06-05
updated: 2026-06-05
author: "@N4M3Z"
project: forge-provision
related:
    - "GPG-0001 GPG on YubiKey.md"
    - "GPG-0002 Elliptic curve keys.md"
    - "GPG-0007 OpenPGP v6 and post-quantum schism.md"
    - "PROV-0010 Proton encryption and keys.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Post-quantum readiness

## Context and Problem Statement

Post-quantum cryptography is arriving asymmetrically across this stack:

- **OpenPGP**: hybrid composite schemes (X25519 + ML-KEM-768 for encryption, Ed25519 + ML-DSA-65 for signing) are defined in the IETF draft, near ratification but not yet an RFC.
- **GnuPG**: ML-KEM encryption exists only in the unstable 2.5.x development series; stable releases have none. Sequoia-PGP gates its support on ratification.
- **Hardware**: YubiKey applets do RSA and ECC only. Post-quantum needs new silicon — current firmware has no upgrade path, and Yubico has shown prototypes but ships no product.
- **SSH**: post-quantum key exchange already ships (ML-KEM-768 hybrid as default), but post-quantum *signatures* do not exist in OpenSSH, whose stated position is that signatures have no store-now-decrypt-later urgency.
- **Proton**: hybrid post-quantum mail keys (OpenPGP v6) are rolling out, opt-in, managed entirely by Proton's clients.

The asymmetry has one clean explanation. Harvest-now-decrypt-later threatens *stored ciphertext* today: an adversary records encrypted data now and decrypts it when quantum computers arrive. A *signature* only needs to resist forgery at verification time — a future quantum break enables future forgeries, not retroactive ones. So post-quantum is urgent for long-lived ciphertext, not for signing, and a hardware-bound key cannot move faster than its silicon regardless.

## Decision Drivers

- Harvest-now-decrypt-later applies to ciphertext, not signatures.
- Never bet a decade-scale identity key on a pre-ratification format.
- A hardware-backed key (GPG-0001) cannot outrun its hardware.
- Free protection should be taken where a managed service carries the complexity.

## Considered Options

1. **Stay classical on the card; enable post-quantum in managed services.** Chosen.
2. **Adopt draft post-quantum now** (GnuPG development branch or Sequoia's experimental branch). Rejected: an unstable format for a long-lived identity, and no card can hold the key — it would surrender the hardware-backed premise for a draft.
3. **Ignore post-quantum until forced.** Rejected: Proton's opt-in costs nothing and protects mail against harvest-now-decrypt-later today, and the revisit triggers deserve recording.

## Decision Outcome

Chosen option: **classical on the card, post-quantum where managed**.

- The YubiKey-resident key stays classical Curve25519 ([GPG-0002](GPG-0002 Elliptic curve keys.md)).
- Proton's post-quantum mail is enabled; the managed service runs the hybrid keys ([PROV-0010](PROV-0010 Proton encryption and keys.md)). A consequence is locked in by hardware: Proton's hybrid keys are neither RSA nor ECC, so they can never be loaded onto a current YubiKey — Proton keys stay in Proton, permanently.
- **Revisit triggers**, any of: a post-quantum-capable YubiKey ships; the OpenPGP post-quantum draft ratifies and lands in the stable tooling signers and verifiers share — which the v6 schism may make Sequoia or FreePG rather than GnuPG ([GPG-0007](GPG-0007 OpenPGP v6 and post-quantum schism.md)); or a long-lived local confidential archive needs harvest-now-decrypt-later protection sooner — in that case, re-encrypt that archive with a hybrid tool rather than rotating the identity key.

### Consequences

- [+] No pre-ratification format bets on a decade-scale key.
- [+] Mail gets harvest-now-decrypt-later protection now, at zero local complexity.
- [-] Long-lived locally encrypted data stays classical until tooling and hardware land — an accepted, recorded exposure.
- [-] The eventual post-quantum migration means a new key on new hardware. That is planned, not feared: signing migrations are cheap, since existing signatures stay verifiable.

## More Information

- [draft-ietf-openpgp-pqc](https://datatracker.ietf.org/doc/draft-ietf-openpgp-pqc/) — the hybrid composite schemes for OpenPGP
- [OpenSSH post-quantum page](https://www.openssh.org/pq.html) — PQ key exchange shipped; signatures explicitly deferred
- [Yubico on post-quantum](https://www.yubico.com/blog/future-proofing-authentication-a-look-at-the-future-of-post-quantum-cryptography/) — prototypes shown, new hardware required
- [Proton post-quantum encryption](https://proton.me/blog/introducing-post-quantum-encryption) — the managed rollout this decision leans on
- [PROV-0010 Proton encryption and keys](PROV-0010 Proton encryption and keys.md) — why Proton keys stay in Proton
