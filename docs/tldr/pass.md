# pass

`pass` keeps every secret as a GPG-encrypted file, so the store inherits the YubiKey custody model ([GPG-0001](../decisions/GPG-0001%20GPG%20on%20YubiKey.md)): decrypting any entry requires the card. `pass-otp` handles TOTP entries inside the same store — still the canonical extension, not superseded.

## Install

```sh
./scripts/install/pass.sh    # pass + pass-otp from Homebrew
```

## Migrate a store to a new key

The store directory carries its key id in `.gpg-id`; migration is one `pass init` with both keys reachable — the old one decrypts, the new one encrypts.

### 1. Old public key

Decryption needs the old card *and* the old public key in the keyring (no trust setting required). If the key was ever registered with GitHub, recover it from there:

```sh
cat <store>/.gpg-id                                          # the old key (often a subkey id)
gh api user/gpg_keys --jq '.[] | "\(.key_id): \([.subkeys[].key_id] | join(", "))"'
gh api user/gpg_keys --jq '.[] | select(.key_id=="<OLD_MASTER>") | .raw_key' | gpg --import
```

### 2. Re-encrypt

```sh
# OLD YubiKey inserted
gpg-connect-agent "scd serialno" "learn --force" /bye
gpg --card-status                        # binds the old subkey stubs to the card

cp -a <store-copy> ~/.password-store     # keep the source copy as the safety net

pass init <NEW_KEYID>                    # decrypts each entry with the old card,
                                         # encrypts to the new key, rewrites .gpg-id
```

A touch per entry happens only if the old card has an encryption touch policy. If any subdirectory carries its own `.gpg-id`, re-init it too: `pass init -p <subdir> <NEW_KEYID>`.

### 3. Verify with the new card, then clean up

```sh
# NEW YubiKey inserted
gpg-connect-agent "scd serialno" "learn --force" /bye
pass show <any-entry>
pass otp <any-otp-entry>                 # if OTP entries exist
rm -rf <store-copy>                      # only after both succeed
```

## Day to day

- Decrypts are card-gated: PIN once per insertion, per the [ARCH-0006](../decisions/ARCH-0006%20Commit%20signing.md) policy.
- After swapping YubiKeys: `gpg-connect-agent "scd serialno" "learn --force" /bye`.
- `pass git <args>` proxies git inside the store. After `pass git init`, every mutation auto-commits — history and undo for secrets, syncable with `pass git push`. Entry names are plaintext paths even though contents are encrypted, so private remotes only. Store commits are bookkeeping, not attestation: `git -C ~/.password-store config commit.gpgsign false` carves them out of global signing (same logic as Entire's checkpoints, [ARCH-0028](../decisions/ARCH-0028%20Session%20persistence%20Entire%20CLI.md)).
- Give the store a `.gitignore` (`.DS_Store`, `._*`) before the first commit — the init commit otherwise sweeps Finder droppings into history. Already-tracked junk: `git ls-files -z | grep -zE '(^|/)\.DS_Store$|(^|/)\._' | xargs -0 git rm --cached --`.
- Completions missing right after install = stale compinit cache. Locate it with `zsh -ic 'echo $_comp_dumpfile'` (frameworks relocate it — prezto uses `~/.cache/prezto/zcompdump`), then `rm` that file and `exec zsh`.

## Decisions behind this

| Decision | Answers |
| --- | --- |
| [GPG-0001](../decisions/GPG-0001%20GPG%20on%20YubiKey.md) | Why store entries are gated by the card |
| [GPG-0005](../decisions/GPG-0005%20GPG%20toolchain%20on%20macOS.md) | Where gpg and pass come from |
| [YubiKey GPG](YubiKey%20GPG.md) | The key these entries are encrypted to |
