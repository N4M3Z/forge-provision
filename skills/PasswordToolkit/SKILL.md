---
name: PasswordToolkit
version: 0.1.0
allowed-tools: Bash(pass *) Bash(pass-cli *)
description: "Command-line secret management with two complementary tools: pass (the standard Unix password-store, GPG/YubiKey-backed, local and git-syncable) and Proton's official pass-cli (E2EE Proton Pass vaults, cross-device, CI token injection). Covers store and retrieve, multiline entries, TOTP, non-interactive scripting, personal access tokens, and pass:// secret injection. USE WHEN storing or retrieving a secret, password, API key, license key, or TOTP from the CLI; using pass / password-store; using Proton Pass / pass-cli; injecting secrets into a script or CI job; or deciding where a credential should live instead of a tracked file."
sources:
    - https://www.passwordstore.org/
    - https://git.zx2c4.com/password-store/about/
    - https://proton.me/blog/proton-pass-cli
    - https://protonpass.github.io/pass-cli/
    - https://github.com/protonpass/pass-cli
---

# PasswordToolkit

Two CLIs cover machine secret management, and they are different tools that are easy to confuse:

- **`pass`** (the standard Unix password-store) stores each secret as a GPG-encrypted file under `~/.password-store`. Decryption is your own GPG key (on the YubiKey, per the GPG-000x ADRs), so a secret is readable only with the hardware present. The store is an ordinary git repo, so it syncs to a private remote if you want. Best for machine-local secrets, anything you want under your own key, and offline-first use. See [Pass.md](Pass.md).
- **`pass-cli`** (Proton's official Proton Pass CLI) reaches your end-to-end-encrypted Proton Pass vaults from the terminal. Best for secrets that already live in Proton Pass, cross-device or shared vaults, and CI token injection via scoped personal access tokens. Requires a paid Pass plan. See [ProtonPass.md](ProtonPass.md).

`pass` and `pass-cli` are distinct binaries with distinct stores. This skill never treats them as interchangeable.

## Current state

!`pass-cli vault list 2>/dev/null || echo "(proton pass-cli: not logged in, run: pass-cli login)"`

## Which tool when

| Need | Tool |
| --- | --- |
| Secret encrypted to your own GPG/YubiKey key, readable offline | `pass` |
| Local-first, optionally synced to a private git remote you control | `pass` |
| A secret that already lives in your Proton Pass vault | `pass-cli` |
| Cross-device or vault-shared secret, managed in the Proton apps | `pass-cli` |
| Inject a secret into a CI job without an interactive login | `pass-cli` (personal access token) |
| TOTP code for a 2FA login from the terminal | either (`pass otp`, or Proton Pass) |

When unsure, default to `pass`: it has no external dependency, no paid tier, and the secret stays under your key.

## Shared discipline (both tools)

- **Never put a secret in argv.** Process arguments are world-visible via `ps`. Feed secrets through stdin, a `--file`, or an env-file, never `--password mysecret`.
- **Never echo a secret into shell history or a log.** Pipe into the tool; do not `echo "$secret"`.
- **Never write a real secret into a tracked file.** A credential belongs in `pass` or Proton Pass, not in a committed `.env`, ADR, or config. Use placeholders in anything git tracks.
- **The decrypt boundary is the hardware.** Both paths ultimately gate on a key you hold (YubiKey GPG for `pass`; your Proton account / token for `pass-cli`). Expect a touch or PIN on read.
- **Clipboard secrets auto-clear.** `pass -c` clears after 45 seconds; prefer it over printing to the terminal.

## Provisioning

- `pass`: installed via `scripts/install/pass.sh` and the Brewfile; quick reference in `docs/tldr/pass.md`. Initialize with `pass init <your-gpg-id>` so entries encrypt to your YubiKey key.
- `pass-cli`: `brew install proton-pass-cli` (homebrew-core), in the Brewfile. Alternative: the SHA256-verified `proton.me/download/pass-cli/install.sh`.

Detailed command surfaces, scripting patterns, and pitfalls live in the per-tool companions rather than here.
