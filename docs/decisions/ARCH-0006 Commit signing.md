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
updated: 2026-05-21
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

`pinentry-mac` (brew cask `pinentry-mac`) handles the PIN entry GUI, wired through `~/.gnupg/gpg-agent.conf`:

```
pinentry-program /opt/homebrew/bin/pinentry-mac
default-cache-ttl 3600
max-cache-ttl 86400
```

The YubiKey holds the OpenPGP signing subkey resident; `gpg-agent` discovers the smartcard on first signing operation and prompts for the PIN via pinentry-mac. Touch the YubiKey when the LED blinks.

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
- [PROV-0003 YubiKey](PROV-0003 YubiKey.md) — YubiKey provisioning details that back both signing paths
- [forge-core CommitSigning skill](https://github.com/N4M3Z/forge-core/blob/main/skills/VersionControl/CommitSigning.md) — SSH-side details for the alternative path
- [pinentry-mac](https://github.com/GPGTools/pinentry) — macOS-native Cocoa pinentry
- [`scripts/configure/git-ssh-sign.sh`](../../scripts/configure/git-ssh-sign.sh) — wrapper installer for the SSH-FIDO2 path
