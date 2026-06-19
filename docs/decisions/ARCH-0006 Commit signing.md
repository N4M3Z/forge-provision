---
title: Commit signing
description: Commits and tags are signed by default via GPG on the YubiKey OpenPGP slot with pinentry-mac for the PIN dialog. SSH-with-FIDO2 (sk-ssh-ed25519) is the alternative, used when a repo prefers SSH signing or GPG isn't available.
type: adr
category: architecture
tags:
    - git
    - signing
    - gpg
    - ssh
    - yubikey
    - pinentry-mac
status: accepted
created: 2026-05-11
updated: 2026-06-20
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0002 New machine provisioning order.md"
    - "PROV-0003 YubiKey.md"
    - "PROV-0010 Proton encryption and keys.md"
    - "ARCH-0028 Session persistence Entire CLI.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Commit signing

## Context and Problem Statement

Signed commits carry cryptographic provenance — readers and CI systems verify that a commit came from someone holding a specific private key. Git supports two signing formats since v2.34: traditional OpenPGP (`gpg.format=openpgp`) and SSH-based (`gpg.format=ssh`). The two have different trust chains, different toolchain footprints, and different ergonomics. They coexist (one config value at a time) on the same machine and same repo; the question is what to make the default.

On macOS specifically, SSH signing with FIDO2 hardware keys hits a friction wall: Apple's launchd `ssh-agent` lacks libfido2 middleware and refuses `sk-ssh-ed25519` operations with "agent refused operation". Workarounds exist (wrapper that strips `SSH_AUTH_SOCK`, replacing the system ssh-agent with brew's) but every one of them is macOS-specific plumbing. GPG with `gpg-agent` + `pinentry-mac` is the macOS-native path — `gpg-agent` talks to the YubiKey OpenPGP slot directly, pinentry handles the PIN dialog as a Cocoa-native GUI, no shim required.

## Decision Drivers

- Hardware-binding the private signing key (no software-on-disk copies)
- Minimal daily toolchain friction on macOS (avoid the Apple ssh-agent + ssh-askpass plumbing for the default path)
- GitHub "Verified" badge via the standard registration flow
- Both signing formats accepted by GitHub/GitLab — flexibility on the signing format is a feature, not a constraint
- An escape path for repos / scenarios where SSH signing is preferred (organization mandate, ssh-only environment)

## Considered Options

1. **GPG-with-YubiKey-OpenPGP + pinentry-mac as default; SSH-with-FIDO2 as alternative.** Native macOS path, no agent shim required. SSH stays available for repos that want it.
2. **SSH-with-FIDO2 as default; GPG opt-in per-repo.** The earlier framing (pre-2026-05-21). Bumped into the macOS ssh-agent issue often enough to flip to GPG-preferred.
3. **OpenPGP-only.** Demands GPG toolchain on every machine even when SSH would do.
4. **SSH-only.** Inherits the macOS ssh-agent friction permanently; no escape for repos preferring GPG.
5. **No signing.** Loses provenance signal entirely.

## Decision Outcome

Chosen option: **GPG-with-YubiKey-OpenPGP + pinentry-mac as the default; SSH-with-FIDO2 as the alternative**.

Default git config:

```sh
git config --global gpg.format openpgp
git config --global user.signingkey <KEY-ID>!         # trailing ! pins to the signing subkey
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

`pinentry-mac` (brew formula `pinentry-mac`) handles the PIN entry GUI, wired through `~/.gnupg/gpg-agent.conf`:

```
pinentry-program /opt/homebrew/bin/pinentry-mac
```

`gpg-agent` caches the verified card PIN, and its cache TTL governs how often the pinentry dialog reappears — not only for on-disk keys. Left at the 600 s default the dialog rarely shows, so the 15 s `cached` touches fall between PIN prompts and surface only as a silent LED blink (a push once timed out on an unnoticed touch). `default-cache-ttl 12` / `max-cache-ttl 15` cap the PIN cache under the touch window, so the pinentry dialog reappears together with each needed touch and becomes the cue to touch. scdaemon needs `disable-ccid` on macOS (GnuPG 2.3+ stopped falling back to PC/SC on its own, and CryptoTokenKit owns the USB device). Both `gpg-agent.conf` and `scdaemon.conf` are managed by chezmoi (`private_dot_gnupg/`; the pinentry path is templated via `lookPath`), and a chezmoi `run_onchange` script disables pinentry-mac's Keychain PIN storage and reloads the agents whenever either conf changes.

The YubiKey holds the OpenPGP signing subkey resident; `gpg-agent` discovers the smartcard on first signing operation and prompts for the PIN via pinentry-mac. Touch the YubiKey when the LED blinks.

**Key material.** Signing keys are elliptic — Curve25519 (ed25519 to certify, sign, and authenticate; cv25519 to encrypt), not RSA. At a comparable or higher security level the keys and signatures are a fraction of RSA's size and on-card operations are faster, which matters most on a constrained device like the YubiKey; the curve's rigid parameters and deterministic signatures also avoid RSA's padding-oracle and weak-randomness footguns. Curve25519 is the recommended choice for new keys across the modern toolchain (GnuPG, OpenSSH, Sequoia/OpenPGP per RFC 9580), and GitHub verifies it identically to RSA; RSA is reserved for FIPS or legacy interop. The master is generated and kept offline; only the subkeys go on the YubiKey via `keytocard`, with `user.signingkey` and `gpg.format openpgp` pointing at the signing subkey.

**Touch cached for signing, PIN per insertion.** The signature slot's touch policy is `cached` — physical presence is still required (a cold card cannot sign), but one touch opens a 15-second window so a burst of small commits costs one touch. Encryption and authentication slots stay `on` (per-operation touch; those operations are rare). Strict touch-per-signature was the original policy, and it observably backfired: the per-commit friction drove batching work into few large commits, degrading history granularity and review quality — while under the squash-merge workflow the per-commit signatures on a PR branch are discarded at merge anyway (GitHub's web-flow key signs the squash commit). The 15-second cache is the measured trade: malware still cannot sign without a deliberate touch first, and granular commits become cheap again. `forcesig` is off, so the card does not demand a PIN per signature; instead `gpg-agent` caches the verified PIN and re-prompts on its cache schedule — capped to the 15 s touch window (above) so a needed touch always arrives with a visible PIN dialog rather than a silent blink. The PIN guards a lost or stolen card rather than each signature. High signing volume from automated tooling is handled by not signing those commits ([ARCH-0028](ARCH-0028 Session persistence Entire CLI.md)), not by weakening the key. pinentry-mac's "Save in Keychain" checkbox is disabled (`DisableKeychain`, via the chezmoi `run_onchange` gnupg script): a Keychain-stored PIN would auto-unlock the card on every insertion, deleting the PIN factor with nothing visible changed.

For repos or scenarios where SSH signing is preferred, opt in per-repo:

```sh
git config gpg.format ssh
git config user.signingkey ~/.ssh/<keyname>.pub
```

The SSH-with-FIDO2 alternative path uses `sk-ssh-ed25519` resident keys (provisioned via `scripts/install/ssh-yubikey-key.sh`) plus the `git-ssh-sign-macos` wrapper (provisioned via `scripts/configure/git-ssh-sign.sh`) to bypass Apple's ssh-agent. See [forge-core skills/VersionControl/CommitSigning.md](https://github.com/N4M3Z/forge-core/blob/main/skills/VersionControl/CommitSigning.md) for the full SSH-side mechanics.

Both modes coexist — the SSH signing key and OpenPGP subkeys live on the same YubiKey (different applets, no conflict), and both register independently with GitHub for Verified-badge eligibility.

### Consequences

- [+] Default flow uses the macOS-native pinentry-mac dialog — no ssh-agent shim, no `SSH_ASKPASS` env propagation puzzles
- [+] `gpg-agent` talks to the YubiKey OpenPGP slot directly — fewer moving parts than SSH+libfido2+wrapper
- [+] Both signing modes share the same YubiKey — one device, multiple uses, easy escape
- [+] GUI-launched processes (IDEs, Spotlight launches) work the same as terminal-launched — no `launchctl setenv` needed for the default path
- [-] GPG toolchain (`gnupg`, `pinentry-mac`) becomes a daily-toolchain dependency on macOS
- [-] OpenPGP key management has its own learning curve (subkeys, expiration, revocation certs)
- [-] SSH-signing path remains supported — when used, it inherits the Apple-ssh-agent friction and needs the wrapper

## More Information

- [Git: `gpg.format` configuration](https://git-scm.com/docs/git-config#Documentation/git-config.txt-gpgformat)
- [GitHub: commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [Mozilla OpenSSH guidelines](https://infosec.mozilla.org/guidelines/openssh) — Ed25519 preferred over RSA for new keys
- [RFC 9580: OpenPGP](https://www.rfc-editor.org/rfc/rfc9580) — standard codepoints for Ed25519 / X25519 keys
- [PROV-0003 YubiKey](PROV-0003 YubiKey.md) — YubiKey provisioning details that back both signing paths
- [forge-core CommitSigning skill](https://github.com/N4M3Z/forge-core/blob/main/skills/VersionControl/CommitSigning.md) — SSH-side details for the alternative path
- [pinentry-mac](https://github.com/GPGTools/pinentry) — macOS-native Cocoa pinentry
- [`scripts/configure/git-ssh-sign.sh`](../../scripts/configure/git-ssh-sign.sh) — wrapper installer for the SSH-FIDO2 path
