---
title: Commit signing
description: Commits and tags are signed by default via SSH; OpenPGP signing is opt-in per-repo for cryptographic identity continuity with an external key
type: adr
category: architecture
tags:
    - git
    - signing
    - ssh
    - gpg
status: accepted
created: 2026-05-11
updated: 2026-05-11
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0002 New machine provisioning order.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Commit signing

## Context and Problem Statement

Signed commits carry cryptographic provenance — readers and CI systems verify that a commit came from someone holding a specific private key. Git supports two signing formats since v2.34: traditional OpenPGP (`gpg.format=openpgp`) and SSH-based (`gpg.format=ssh`). The two have different trust chains, different toolchain footprints, and different ergonomics. They coexist (one config value at a time) on the same machine and same repo; the question is what to make the default and when to opt into the alternative.

## Decision Drivers

- Hardware-binding the private signing key (no software-on-disk copies)
- Minimal daily toolchain — `gpg-agent` / `pinentry` overhead, or none
- Single key serving multiple purposes (auth + signing) where possible
- GitHub "Verified" badge via the standard registration flow
- An escape path for repos where cryptographic continuity with an external OpenPGP identity matters (signing as a managed-mail-service identity, for example)

## Considered Options

1. **SSH-signing by default, opt-in OpenPGP per-repo** — modern, GPG-free baseline; OpenPGP available for repos/commits where cryptographic continuity with an external key is wanted
2. **OpenPGP-only** — traditional; demands a working GPG toolchain on every machine; daily toolchain overhead applies even to repos where it adds no value
3. **SSH-signing only** — simplest; no path for cryptographic continuity with an external OpenPGP identity
4. **No signing** — fastest setup; loses provenance signal

## Decision Outcome

Chosen option: **SSH-signing by default, opt-in OpenPGP per-repo**. Default git config: `gpg.format=ssh`, signing key is a YubiKey-resident FIDO2 ed25519-sk credential (provisioning details in [PROV-0003](PROV-0003 YubiKey.md)). For repos where commits should be signed by an external OpenPGP identity (e.g. an OpenPGP key managed by a mail service), per-repo `git config gpg.format openpgp` flips to the GPG path. Both modes coexist — the SSH signing key and OpenPGP subkeys can live on the same YubiKey (different applets, no conflict), and both register independently with GitHub for Verified-badge eligibility.

### Consequences

- [+] Default flow needs no GPG keychain — daily commits don't pay the GPG toolchain tax
- [+] OpenPGP path remains available for repos where it adds value
- [+] Both modes share the same YubiKey — one device, multiple uses
- [-] Two signing chains to understand; per-repo switching adds a small mental cost
- [-] OpenPGP tooling (`gnupg`, `pinentry-mac`, etc.) only gets exercised when the opt-in path is used — can drift unnoticed if rarely invoked

## More Information

- [Git: `gpg.format` configuration](https://git-scm.com/docs/git-config#Documentation/git-config.txt-gpgformat)
- [GitHub: commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [PROV-0003 YubiKey](PROV-0003 YubiKey.md) — YubiKey provisioning details that back both signing paths
