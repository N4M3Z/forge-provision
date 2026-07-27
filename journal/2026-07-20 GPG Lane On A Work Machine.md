# 2026-07-20 GPG Lane On A Work Machine

The work laptop's GPG setup diverged from what the scripts assumed, and the
divergence was invisible until a commit refused to sign. Four differences,
found by inspecting the machine rather than the manifests.

## What the machine actually had

- **Two gpg builds.** Homebrew `gnupg` 2.5.21 on `PATH` and GPG Suite's
  MacGPG 2.2.41 at `/usr/local/MacGPG2`, plus GPG Keychain, GPGServices, and
  GPGPreferences. [GPG-0005](../docs/decisions/GPG-0005 GPG toolchain on macOS.md)
  keeps exactly one gpg on the machine, so the Suite is the one to go.
- **Two owners for git signing.** `scripts/configure/git-signing-ssh.sh`
  writes `gpg.format=ssh`; the chezmoi-managed gitconfig writes
  `gpg.format=openpgp`. Whichever ran last decided how commits sign, and
  chezmoi won. No arbiter existed.
- **No script for the default lane.**
  [ARCH-0006](../docs/decisions/ARCH-0006 Commit signing.md) makes
  OpenPGP-on-YubiKey the default and SSH/FIDO2 the alternative, yet only the
  alternative was automated. Provisioning could not configure the documented
  default.
- **A signing config from another machine.** The deployed `~/.gitconfig`
  pointed `gpg.ssh.allowedSignersFile` and the signing program at
  `/Users/N4M3Z/...`, a home directory that does not exist here. The source
  file is static, not a chezmoi template, so the author's absolute paths reach
  every machine verbatim.

## What changed

- `scripts/configure/git-signing-openpgp.sh` (new) configures the ARCH-0006
  default: signing subkey pinned with a trailing `!`, `gpg.format=openpgp`,
  and `gpg.program` set to an explicit binary so a second gpg on `PATH`
  cannot decide which one git calls.
- `git-signing-ssh.sh` defers when the OpenPGP lane is already configured,
  overridable with `FORGE_SIGNING_LANE=ssh`. The two lanes no longer race;
  the default wins and the alternative is opt-in. Alphabetical ordering puts
  the default first in a topic pass.
- `gpg-toolchain.sh` enumerates the GPG Suite components and receipts it
  finds, names which gpg git currently resolves to, and removes them on
  request. Removal takes the Homebrew path when Homebrew owns the cask, since
  `brew uninstall --cask` runs the vendor's own uninstaller from the Caskroom
  and that uninstaller knows every component it installed. Receipt-based
  removal remains the fallback for a GPG Suite that Homebrew does not own.
  Either path requires `FORGE_REMOVE_GPG_SUITE=1` and an interactive terminal,
  so a topic pass never touches system paths as a side effect, and `~/.gnupg`
  is never touched, since it holds the keyring rather than the Suite.
- `scripts/verify/signing.sh` (new) asserts the configured lane can actually
  sign. A signing key with no available secret fails. A path setting is judged
  against the active lane: a missing path the lane depends on fails, while the
  `gpg.ssh.*` pair merely warns under `gpg.format=openpgp`, where it is inert.
  A path under another machine's home fails either way, since that is wrong
  whether the lane uses it or not. All of it used to surface at the first
  commit instead of at provision time.

## Still open

The static `dot_gitconfig` in the dotfiles repo needs to become a template
using `{{ .chezmoi.homeDir }}`; until then every machine inherits the author's
paths. `verify/signing.sh` catches the symptom, not the cause.
