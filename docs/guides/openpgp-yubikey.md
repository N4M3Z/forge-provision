# OpenPGP on a YubiKey that also handles macOS login

Use one compatible YubiKey for OpenPGP signing, encryption and SSH authentication
while preserving its existing PIV credentials. This is an opt-in macOS ceremony,
not a baseline provisioning task. It requires Python 3.10+, GnuPG 2.4+, YubiKey
Manager 5.x, `pinentry-mac`, `paperkey`, `qrencode`, and a YubiKey that supports
Ed25519 and Curve25519 OpenPGP keys. Connect it over USB for this workflow.

## Check both applications first

PIV and OpenPGP are separate applications with separate credentials. Empty
OpenPGP slots do not mean the whole YubiKey is empty. `gpg --card-status` describes
OpenPGP, while `ykman piv info` inventories PIV certificates.
[Yubico application overview](https://developers.yubico.com/Developer_Program/Guides/User_Loaded_Data.html#_applications).

PIV slot **9A** is authentication, including system login. **9D** is key
management, including decryption; it is not a second login certificate or a
mandatory prerequisite for this helper. The helper snapshots every reported
PIV certificate and compares the inventory after setup and on resume.
[Yubico PIV slot reference](https://docs.yubico.com/hardware/yubikey/yk-tech-manual/yk5-apps-piv.html#slot-information).

`keytocard` writes OpenPGP slots. The helper never issues PIV mutations, resets,
pairing changes, or USB application changes. Preserved certificate fingerprints
are evidence about the certificates, not proof of working login or matching
private keys. Test macOS login separately before retiring another device.
[Apple smartcard integration](https://support.apple.com/guide/deployment/intro-to-smart-card-integration-depd0b888248/web).

## 1. Supply your own identity and device

Install the required tools before disconnecting networking:

```sh
brew install gnupg pinentry-mac ykman paperkey qrencode
ykman list --serials
```

Keep only the target YubiKey connected for setup. Set these public identity values
locally, or put them in the ignored `.env`. Replace the examples before running:

```sh
export OPENPGP_NAME='Example Developer'
export OPENPGP_EMAIL='developer@example.com'
export OPENPGP_SERIAL='YOUR_DECIMAL_SERIAL'
bash scripts/configure/openpgp-yubikey.sh --dry-run --name "$OPENPGP_NAME"
bash scripts/configure/openpgp-yubikey.sh --check
```

The bare wrapper and bare `--dry-run` skip safely during ordinary provisioning.
An explicitly configured dry run validates arguments without reading cards or
creating files. `--check` reads device metadata and checks prerequisites. For an existing image,
use `--check --resume`. Unknown metadata layouts stop before card writes; the
parser requires the supported ykman 5.x summary fields even when slots are empty.

Default locations:

| Purpose | Location |
| --- | --- |
| Encrypted recovery image | `~/.local/share/keyvaults/openpgp.gpg.dmg` |
| Temporary mounted vault | `/Volumes/OpenPGP Vault` |
| Public exports and local result report | `~/.local/share/keyvaults/openpgp-public/` |

Override these with `--image`, `--mount`, and `--output-dir`. Use the same values
on resume. Keep all runtime artifacts outside the repository. Public keys and
reports still identify their owner and device; share them only intentionally.

## 2. Create the encrypted recovery vault

Disconnect Wi-Fi, Ethernet and VPNs, then run in your own terminal:

```sh
bash scripts/configure/openpgp-yubikey.sh --name "$OPENPGP_NAME"
```

Enter the disk-image password, key passphrase, and PINs only in the local native
prompts. Do not pass them as command arguments or send them to an agent.

The helper creates an AES-256 encrypted APFS image. Inside it, GnuPG generates a
certification-only Ed25519 primary key and three subkeys: Ed25519 signing,
Curve25519 encryption, and Ed25519 authentication. Subkeys expire after two years;
the primary does not expire. Keep renewal and revocation responsibility in mind.

The certification primary stays in the encrypted vault. Full secret exports,
subkey exports, revocation material and paperkey recovery data are saved there
before any card transfer. The helper closes and reopens the image, reconstructs
the paperkey backup in an isolated keyring, and tests signing and decryption.
This tests the local recovery copy, not a copy on another disk or cloud service.

Networking can be deliberately left available with either equivalent flag:

```sh
bash scripts/configure/openpgp-yubikey.sh --allow-online
# Equivalent, including on resume:
bash scripts/configure/openpgp-yubikey.sh --resume --ignore-network
```

The bypass skips the offline confirmation and all route checks for that run.
It is recorded in the local report and does not silently enable later runs.
Route checks alone cannot prove isolation; explicit disconnection remains the
default operating procedure.

## 3. Change OpenPGP PINs and transfer the subkeys

The prompts change the **OpenPGP user PIN** and **OpenPGP Admin PIN**. They do not
ask for the PIV PIN, PIV PUK, or macOS password. Factory values are user `123456`
and admin `12345678`, only if you have never changed them. A wrong attempt consumes
a retry. Stop if you do not know the current value; do not guess or reset.

On an interrupted change, the numbered chooser offers:

1. Retry the change using the known current PIN, if the previous attempt failed.
2. Skip because the change already succeeded, if you know it did.

The helper prints a command guide **before** handing over to `gpg>`. For a fresh
transfer, enter each command separately and verify the selected subkey and slot:

| At `gpg>` | Action |
| --- | --- |
| `key 1` | Select signing `[S]` |
| `keytocard` | Choose **Signature**, normally option `1` |
| `key 1` | Deselect signing |
| `key 2` | Select encryption `[E]` |
| `keytocard` | Choose **Encryption**, normally option `2` |
| `key 2` | Deselect encryption |
| `key 3` | Select authentication `[A]` |
| `keytocard` | Choose **Authentication**, normally option `3` |
| `key 3` | Deselect authentication |
| `save` | Save the card references and return to the helper |

Never transfer the certification primary. Resume prints only missing transfers;
an occupied slot must match the saved subkey fingerprint or setup stops.

The next prompts explain the touch policies before asking for the Admin PIN:

| Slot label | Purpose | Configured policy |
| --- | --- | --- |
| SIG | Signing | `cached`: reuse a touch for 15 seconds |
| DEC | Decryption | `on`: touch for each operation |
| AUT | Authentication, including SSH | `on`: touch for each operation |

The helper verifies all three card fingerprints, tests card signing and
decryption from a public-only keyring, checks PIV certificates again, publishes
the public exports, and unmounts the vault. SSH and macOS login still need their
own end-to-end checks.

## 4. Resume or recover

For an interruption after recovery exports were saved:

```sh
bash scripts/configure/openpgp-yubikey.sh --resume
```

Use the same identity, serial and path options. It reopens the existing image,
checks its saved identity and PIV snapshot, re-verifies recovery, and resumes
PIN, transfer and touch-policy steps. It never generates a replacement identity
over an existing image. See [recovery instructions](openpgp-recovery.md) for
earlier failures, busy mounts or unexpected card contents.

Keep the encrypted vault closed between uses. If you choose an external or cloud
backup, copy the closed DMG and separately verify that copy opens and recovers.
The helper does not create or claim to verify an external backup.

## 5. Migrate pass and configure signing and SSH

Follow [password-store migration](password-store-migration.md) for the native
`pass init` command and the optional staged verification helper.

Import only the public certificate into your everyday GPG home and let GnuPG
learn the connected card references. Keep the certification secret in the vault:

```sh
gpg --import "$HOME/.local/share/keyvaults/openpgp-public/openpgp-public.asc"
gpg --card-status
gpg --with-subkey-fingerprint --list-secret-keys NEW_PRIMARY_FINGERPRINT
```

### Scope Git signing to the intended repositories

Set the commit email to an address verified on the destination forge and present
on the OpenPGP certificate. Upload that public certificate to the intended account.
Git signing and SSH use different public-key formats and separate registrations.
[GitLab GPG verification](https://docs.gitlab.com/user/project/repository/signed_commits/gpg/).

For one repository, configure these values locally, using the full signing
subkey fingerprint followed by `!` to select it exactly:

```sh
git config --local user.name 'Example Developer'
git config --local user.email 'developer@example.com'
git config --local user.signingkey 'SIGNING_SUBKEY_FINGERPRINT!'
git config --local gpg.format openpgp
git config --local gpg.program "$(command -v gpg)"
git config --local commit.gpgsign true
```

For several repositories, a separate local Git config can be included by remote
URL. For example, put the identity and signing settings in `~/.gitconfig-work`
and these conditions in `~/.gitconfig`:

```gitconfig
[includeIf "hasconfig:remote.*.url:git@git.example.com:*/**"]
    path = ~/.gitconfig-work
[includeIf "hasconfig:remote.*.url:https://git.example.com/**"]
    path = ~/.gitconfig-work
```

The scp-style condition needs `:*/**` to cover group/project paths and subgroups;
do not substitute `:**`. Add an explicit pattern if you use `ssh://` remotes or
a host alias. Do not put remote URLs in the conditionally included file.
[Git conditional includes](https://git-scm.com/docs/git-config#_conditional_includes).

Check the effective identity and key inside both a matching repository and an
unrelated one. Make and verify a signed test commit in a disposable matching
repository before relying on it for real commits. Do not disable signing to work
around an unavailable old key; correct the scope or connect the intended key.

### Scope SSH to the authentication subkey

Register `openpgp-auth.pub` as an SSH key on the intended forge. Obtain the actual
agent socket with `gpgconf --list-dirs agent-ssh-socket`, then add a host-specific
entry to your local SSH config, replacing the socket placeholder:

```sshconfig
Host git.example.com
    User git
    IdentityAgent /absolute/path/from/gpgconf/agent-ssh-socket
    IdentityFile ~/.local/share/keyvaults/openpgp-public/openpgp-auth.pub
    IdentitiesOnly yes
```

Start the agent with `gpgconf --launch gpg-agent` before testing. Keep this socket
selection host-specific so other hosts retain their existing SSH agent. A public
`IdentityFile` selects the matching private key held by the agent.
[OpenSSH configuration](https://man.openbsd.org/ssh_config),
[GnuPG agent options](https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html).

```sh
command ssh -T git@git.example.com
```

If ordinary `ssh` needs two touches but `command ssh` needs one, inspect the
interactive shell first with `type -a ssh`. Ghostty can wrap `ssh` to install
terminfo using an extra connection before the requested connection. A Git-only
server can reject the installation yet accept the second authentication.
Bypassing that wrapper is useful for this test; Git normally invokes the SSH
executable directly. Check custom `core.sshCommand` or `GIT_SSH_COMMAND` settings
if behavior differs. Keep authentication touch protection enabled.
[Ghostty SSH integration](https://ghostty.org/docs/features/ssh).

### Smartcard access conflicts

GnuPG's direct CCID access can contend with macOS smartcard services. The ceremony
uses `disable-ccid` and `pcsc-shared` only in its temporary GPG homes and stops
those agents before YubiKey Manager operations. Shared PC/SC access has caveats;
do not blindly copy these settings into a global configuration or kill unrelated
agents. Inspect reader contention separately from PIN errors or missing keys.
[GnuPG scdaemon options](https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html).

## Completion checklist

- [ ] Recovery exports reconstruct the intended identity inside the vault.
- [ ] OpenPGP S/E/A fingerprints match the selected card.
- [ ] PIV certificate inventory is unchanged, and macOS login works separately.
- [ ] The new card decrypts migrated passwords with the old card disconnected.
- [ ] A signed Git commit verifies under the intended repository identity.
- [ ] SSH authenticates to the intended account with the intended key.
- [ ] The encrypted image is unmounted; any chosen external copy is verified.
- [ ] Old keys remain available for rollback and historical ciphertext.
