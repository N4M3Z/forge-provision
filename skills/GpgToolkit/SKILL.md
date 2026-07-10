---
name: GpgToolkit
version: 0.1.0
description: "GPG key custody and commit signing on macOS with a YubiKey: offline primary key, subkeys on card, Homebrew toolchain, pinentry, paperkey backup, key-vault scaffold, GitHub key endpoints and UID hygiene, verification debugging. USE WHEN setting up GPG signing, gpg signing failed or Timeout, YubiKey OpenPGP, sec# or ssb> stubs, adding a GPG UID, commit shows Unverified or bad_email, exporting or backing up GPG keys, paperkey, key vault."
---

# GpgToolkit

@GitHubKeyEndpoints.md

GPG key custody and signing for this machine's model: the primary certify key `[C]` lives offline in an encrypted key vault, daily subkeys live on the YubiKey (`ssb>`), and a `sec#` stub in `gpg -K` is correct, not broken. Decisions: `docs/decisions/GPG-0001` (custody), `GPG-0004` (generation ceremony), `GPG-0005` (toolchain), `GPG-0006` (physical backup), `ARCH-0006` (signing).

## Scripts

| Script | Does |
| ------ | ---- |
| `scripts/install/gpg-toolchain.sh` | Homebrew gnupg 2.5.x toolchain (not GPG Suite); idempotent |
| `scripts/install/paperkey.sh` | paperkey + qrencode for printed key backup |
| `scripts/configure/keyvault-scaffold.sh` | Offline key-vault layout on a mounted encrypted volume; secret-free, run before moving key material in |

## Signing configuration

Git signs with `gpg.format=openpgp` via the YubiKey and pinentry-mac; SSH-with-FIDO2 signing is the documented fallback, not the default. jj repos sign batched at push (`signing.behavior=drop` + `git.sign-on-push=true`); a locally-unsigned jj commit is the model working, see VersionControl's Jujutsu companion. Never switch signing method or disable signing to get past a prompt failure.

## Troubleshooting

| Symptom | Meaning and fix |
| ------- | --------------- |
| `gpg: signing failed: Timeout` | pinentry could not prompt from a non-interactive shell. Export `GPG_TTY`, let pinentry-mac raise the PIN dialog, or run the command from the user's own terminal. Not a method problem. |
| `sec#` in `gpg -K` | Primary key stub; the real primary is in the offline vault. Expected. UID changes are an offline ceremony: add the UID there, re-export, re-import everywhere the key lives. |
| Commit shows Unverified, reason `bad_email` | Committer email must match a UID on the signing key AND a verified account email. Inspect with `gh api repos/<owner>/<repo>/commits/<sha> --jq '.commit.verification'`. GitHub re-verifies retroactively once the key matches. |
| Key updated but not recognized somewhere | Key blocks never sync. Each keyring and GitHub hold independent copies; import or paste the updated block explicitly everywhere it lives. |

## Constraints

- Key material never leaves the vault or the card; the scaffold script writes only docs and empty directories
- GPG UIDs are public identity statements (GitHub publishes keys unauthenticated); only names and addresses that may appear on the open web belong there
- Backup before any key operation: paperkey output plus the vault copy, per GPG-0006
