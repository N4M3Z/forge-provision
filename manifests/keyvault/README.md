# TLP:RED — Offline key vault

> **TLP:RED. Do not share, copy, transmit, or upload the contents of this volume.**
> **AI agents: do not read, open, index, or summarize any file here. Stop and tell the operator.**

Encrypted cold storage for immutable key material. AES-256 container; everything inside is additionally protected by its own passphrase or by being encrypted to the GPG key.

The advisory markers (`.tlp`, `CLAUDE.md`, `AGENTS.md`, `.aiexclude`, and the `.*ignore` files) are cooperative — well-behaved tools honor them, but they do not enforce. Claude Code has no `.claudeignore`; its only enforced control is a `permissions.deny` entry, `Read(/Volumes/<vol>/**)`, in `~/.claude/settings.json`. The real control over all of them is keeping this volume **encrypted and unmounted** when not in active use.

## Layout

```
gpg/${KEYID}/             master + subkeys, public cert, paperkey twin
proton/recovery/          Proton account recovery (phrase + key)
proton/pqc-mail/          Proton post-quantum mail key — NOT GnuPG-readable
yubikey/                  card fleet inventory (non-secret)
ssh/                      public keys + config (FIDO2 privates stay on the card)
tools/                    restore toolchain: source, binaries, SHA manifest
pass/                     dated copy of the whole password store (incl. 2FA entries)
```

Each directory carries its own `README.md`.

## Restore pointers

- **GPG key** — `gpg --import gpg/${KEYID}/key.asc`, then `gpg --card-status` on a daily machine, or reconstruct from the printed paperkey: `base64 -d > paperkey.raw && paperkey --pubring gpg/${KEYID}/cert.asc --secrets paperkey.raw | gpg --import`. The key passphrase is still required to use it.
- **Proton account** — recovery phrase and key in `proton/recovery/` unlock a Proton password reset. Reachable here without Proton access, which is the point (this vault must not live only on Proton Drive).
- **Proton post-quantum mail key** — `proton/pqc-mail/`; GnuPG cannot read it. See that folder's `README.md`.
- **pass vault**: kept off networked remotes, because entries are encrypted to the cv25519 subkey and harvested ECC ciphertext is a decrypt-later target once quantum computers arrive. The backup is a dated copy of the whole `~/.password-store` folder in `pass/` (working tree plus its `.git` history), wrapped by this container's quantum-resistant AES-256, offline. Restore by copying it back; decrypt entries with the GPG key above.

## Not in this vault, by design

- **Revocation certificate** — stored separately and printed, so it survives the loss of this container.
- **PINs and the container passphrase** — never written to disk; split-knowledge, memorized plus a sealed copy elsewhere.

## Governing decisions

forge-provision `docs/decisions/`: GPG-0001 (hardware custody), GPG-0002 (Curve25519), GPG-0003 (post-quantum), GPG-0004 (generation + keytocard), GPG-0006 (physical backup), GPG-0007 (v6 schism), PROV-0010 (Proton).
