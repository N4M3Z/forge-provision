# YubiKey GPG

End-to-end setup of a hardware-backed GPG identity: a Curve25519 key generated offline, subkeys moved to one or more YubiKeys, backed up on paper and encrypted media, wired into git signing. Commands here, reasons in the decisions — start at [PROV-0015 GPG](../decisions/PROV-0015%20GPG.md) for the index.

## Prerequisites

```sh
./scripts/install/gpg-toolchain.sh    # gnupg, pinentry-mac, ykman (GPG-0005)
./scripts/install/paperkey.sh         # paperkey, qrencode (GPG-0006)
./scripts/configure/gnupg.sh          # ~/.gnupg, gpg-agent.conf, scdaemon.conf
gpg --version | head -1               # expect 2.5.x from Homebrew
```

Have ready: the YubiKeys, two USB sticks, a direct-attached printer, paper and a pen for the passphrase, and an envelope.

## The ceremony

Run in a fresh terminal. Turn networking off after the prerequisites and keep it off until "Daily machine". The passphrase you choose protects the offline backup forever — the card PINs are separate.

### 1. Throwaway keyring

```sh
export GNUPGHOME=$(mktemp -d)
```

### 2. Certify-only master, never expires

```sh
gpg --expert --full-generate-key
#   (11) ECC (set your own capabilities) → S (drop Sign; Certify stays) → Q
#   → (1) Curve 25519 → 0 (never expires) → name + email → your passphrase
export KEYID=$(gpg -k --with-colons | awk -F: '/^pub/{print $5; exit}')
```

### 3. Subkeys: sign, encrypt, authenticate

```sh
gpg --expert --edit-key "$KEYID"
#   addkey → (10) ECC (sign only)                → Curve 25519 → 2y
#   addkey → (12) ECC (encrypt only)             → Curve 25519 → 2y
#   addkey → (11) ECC → A on, S off (auth only)  → Q → Curve 25519 → 2y
#   save
```

Why this shape: [GPG-0004](../decisions/GPG-0004%20OpenPGP%20key%20generation%20and%20backup.md) (offline master + keytocard), [GPG-0002](../decisions/GPG-0002%20Elliptic%20curve%20keys.md) (why Curve25519).

### 4. Back up — before any keytocard

`keytocard` + `save` replaces the local secret with a stub. Backup happens first, always.

```sh
hdiutil create -size 64m -fs APFS -encryption AES-256 -volname GPGBackup -attach ~/gpg-backup.dmg
export BACKUP="/Volumes/GPGBackup/$KEYID" && mkdir -p "$BACKUP"
gpg --output "$BACKUP/key.asc"         --armor --export-secret-keys "$KEYID"
gpg --output "$BACKUP/subkeys.key.asc" --armor --export-secret-subkeys "$KEYID"
gpg --output "$BACKUP/cert.asc"        --armor --export "$KEYID"
gpg --output ~/revoke-"$KEYID".asc --gen-revoke "$KEYID"
gpg --export-secret-keys "$KEYID" | paperkey --output-type raw | base64 | qrencode -o "$BACKUP/paperkey-qr.png"
gpg --export-secret-keys "$KEYID" | paperkey > "$BACKUP/paperkey.txt"
```

Layout: one directory per key — `key.asc` is the transferable secret key (master plus subkeys), `subkeys.key.asc` the secret subkeys only, `cert.asc` the public certificate. The revocation certificate never lands on the volume.

Then distribute, per [GPG-0006](../decisions/GPG-0006%20Physical%20key%20backup.md):

- Print `paperkey-qr.png` and `paperkey.txt` on the direct-attached printer — paper is the archival anchor.
- Clone the `.dmg` to the second USB; USB copies get re-verified and rewritten about annually.
- The revocation certificate (`~/$KEYID-revoke.asc`) goes to a location separate from the key backups.
- The passphrase goes on paper into a sealed envelope at a second location.

### 5. Per YubiKey — repeat this block for each card

Each card gets the same subkeys but its own PINs and its own touch policy.

```sh
export GNUPGHOME=$(mktemp -d)
gpg --import "/Volumes/GPGBackup/$KEYID/key.asc"
gpg --card-edit
#   each line below is a command typed at the gpg/card> prompt:
#   admin
#   passwd      → 1 (PIN, default 123456) → 3 (Admin PIN, default 12345678) → q
#   login       → your identity
#   name        → surname, given name        (optional cardholder metadata)
#   lang        → en                         (optional)
#   forcesig    → toggles "Signature PIN" to not forced: one PIN per insertion
#   quit
gpg --edit-key "$KEYID"
#   key 1 → keytocard → (1) Signature  → key 1
#   key 2 → keytocard → (2) Encryption → key 2
#   key 3 → keytocard → (3) Authentication → save
gpgconf --kill gpg-agent scdaemon   # release scdaemon's card lock, or ykman hangs after the PIN prompt
ykman openpgp keys set-touch sig cached && ykman openpgp keys set-touch enc on && ykman openpgp keys set-touch aut on
```

If `ykman`'s PIN prompt accepts typing but Enter does nothing (or echoes `^M`): the terminal is sending an untranslated CR to a raw-mode prompt — observed in cmux, where Shift+Enter (LF) submits; Terminal.app needs no workaround. The other known hang is scdaemon's card lock after gpg use: `gpgconf --kill gpg-agent scdaemon`, replug the key, retry; close Yubico Authenticator if it is running. In `gpg --card-status`, `PIN retry counter: 3 0 3` is the healthy factory state — the middle counter is the optional Reset Code, unset by default; a failed prompt never reaching the card leaves the counters untouched.

PIN policy: `forcesig` is toggled off, so the card holds PIN verification from first use until unplugged — one PIN per insertion, while the touch still gates every signature ([ARCH-0006](../decisions/ARCH-0006%20Commit%20signing.md)). Card settings (`forcesig`, `name`, `lang`, touch policy) are per-card: repeat them on every YubiKey.

Touch policy: `cached` on the signature slot, `on` for encryption and authentication. `cached` still requires physical touch — a cold card cannot sign — but one touch opens a 15-second window, so a burst of small commits costs one touch instead of one per commit. Strict touch-per-signature observably drove batching work into few large commits, degrading history granularity; and under a squash-merge workflow the per-commit signatures on a PR branch are discarded at merge anyway (GitHub's web-flow key signs the squash commit), so those touches bought nothing durable. Rationale in [ARCH-0006](../decisions/ARCH-0006 Commit signing.md).

## Daily machine

Networking can come back on. Close the ceremony terminal.

```sh
unset GNUPGHOME
gpg --import "/Volumes/GPGBackup/$KEYID/cert.asc"
gpg --edit-key "$KEYID"            # trust → 5 → save
gpg --card-status                  # binds stubs to the inserted card
gpg -K --keyid-format 0xlong       # the ssb line tagged [S] is the signing subkey
git config --global gpg.format openpgp
git config --global user.signingkey 0x<SIGNING_SUBKEY_ID>!     # trailing ! pins the subkey
git config --global commit.gpgsign true
gh gpg-key add "/Volumes/GPGBackup/$KEYID/cert.asc"
hdiutil detach /Volumes/GPGBackup
git commit --allow-empty -m "test: signed commit"   # PIN prompt + key blink = working
```

## Day to day with several cards

Stubs point at one card's serial. After swapping cards:

```sh
gpg-connect-agent "scd serialno" "learn --force" /bye
```

## Before trusting the backup

A restore drill gates trust ([GPG-0006](../decisions/GPG-0006%20Physical%20key%20backup.md)): on an air-gapped boot, restore from the paper copy and from each USB, confirm the fingerprint matches, test a sign and a decrypt. Re-verify USB copies annually, paper every few years.

QR restore: scan, then `base64 -d > paperkey.raw`, then `paperkey --pubring cert.asc --secrets paperkey.raw | gpg --import` (the QR holds base64 because qrencode rejects raw binary's NUL bytes).

## Decisions behind this guide

| Decision | Answers |
| --- | --- |
| [GPG-0001](../decisions/GPG-0001%20GPG%20on%20YubiKey.md) | Why GPG stays, and why its keys live on hardware |
| [GPG-0002](../decisions/GPG-0002%20Elliptic%20curve%20keys.md) | Why Curve25519, not RSA |
| [GPG-0003](../decisions/GPG-0003%20Post-quantum%20readiness.md) | Why classical now; when to revisit |
| [GPG-0004](../decisions/GPG-0004%20OpenPGP%20key%20generation%20and%20backup.md) | The ceremony itself |
| [GPG-0005](../decisions/GPG-0005%20GPG%20toolchain%20on%20macOS.md) | Why Homebrew, not GPG Suite |
| [GPG-0006](../decisions/GPG-0006%20Physical%20key%20backup.md) | Backup media, split knowledge, restore drill |
| [GPG-0007](../decisions/GPG-0007%20OpenPGP%20v6%20and%20post-quantum%20schism.md) | Why v6/post-quantum exports stay out of this keyring |
| [ARCH-0006](../decisions/ARCH-0006%20Commit%20signing.md) | GPG as the default signing format; touch and PIN policy |
