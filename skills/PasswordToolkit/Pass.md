# Pass (password-store)

The standard Unix password manager. Each secret is a GPG-encrypted file under a directory tree; the tree is an ordinary git repo. Version verified: `pass` 1.7.4 at `/opt/homebrew/bin/pass`.

## Store model

- Store root: `~/.password-store` (override with `PASSWORD_STORE_DIR`).
- Each entry is `<path>.gpg`, encrypted to the GPG id(s) set at `pass init`.
- Entry paths are hierarchical: `software/istat-menus`, `email/proton`, `api/anthropic`. The hierarchy is just directories, organize by domain.
- **Multiline convention:** line 1 is the secret itself; subsequent lines are metadata (`login:`, `url:`, an `otpauth://` URI). Tools that read "the password" take line 1; everything else is yours to parse.

## Initialize

```sh
pass init <your-gpg-id>          # encrypts all entries to this key (the YubiKey key)
pass git init                    # make the store a git repo for history
```

`pass init` with multiple gpg-ids encrypts to all of them (useful for a backup key). Re-running `init` with a new id re-encrypts the whole store.

## Command surface

| Command | What it does |
| --- | --- |
| `pass ls [subfolder]` | List the tree (or a subtree). |
| `pass find <terms>` | List entries whose names match. |
| `pass show <path>` | Decrypt and print the entry (whole file). |
| `pass show -c[N] <path>` | Copy line N (default 1) to the clipboard; auto-clears in 45s. |
| `pass grep <string>` | Decrypt every entry and search the contents. |
| `pass insert [-e|-m] [-f] <path>` | Add an entry. `-e` echo single line, `-m` multiline until EOF, `-f` overwrite. |
| `pass edit <path>` | Decrypt to a tmpfile, open `$EDITOR`, re-encrypt. |
| `pass generate [-n] [-c] [-i|-f] <path> [len]` | Generate a random secret (default 25 chars; `-n` no symbols; `-i` replace only line 1). |
| `pass rm [-r] [-f] <path>` | Remove an entry or subtree. |
| `pass mv [-f] <old> <new>` | Move/rename, re-encrypting. |
| `pass cp [-f] <old> <new>` | Copy, re-encrypting. |
| `pass git <args...>` | Run git in the store (commit/push/remote). |
| `pass otp <path>` | Generate a TOTP code from a stored `otpauth://` URI (pass-otp extension, installed). |

## Intent to flag

| Intent | Command |
| --- | --- |
| Store an app license without it touching argv or history | `printf '%s' "$serial" \| pass insert -e software/istat-menus` |
| Store a secret with metadata (login, url) | `pass insert -m software/foo` then type lines, end with Ctrl-D |
| Read just the secret (line 1) for a script | `pass show software/foo \| head -1` |
| Read a named field | `pass show software/foo \| awk -F': ' '/^login:/{print $2}'` |
| Put a password on the clipboard, not the screen | `pass -c software/foo` |
| Generate and store a new random password | `pass generate -n api/service 32` |
| Get a TOTP code | `pass otp email/proton` |
| Rotate only the password, keep metadata | `pass generate -i software/foo` |

## Non-interactive store (scripting)

`pass insert` prompts on a TTY. To store without prompting, pipe stdin:

```sh
printf '%s' "$secret" | pass insert -e -f path/to/entry          # single line
printf 'topsecret\nlogin: alice@example.com\nurl: https://x\n' \
    | pass insert -m -f path/to/entry                            # multiline
```

Feeding the secret through a pipe keeps it out of argv (`ps`-visible) and out of shell history. Never pass the secret as a command argument.

## GPG / YubiKey behaviour

`pass` calls `gpg`, which delegates private-key operations to `gpg-agent`. With the key on a YubiKey:

- First decrypt in a session prompts for the card PIN (and a touch if the key requires touch). `gpg-agent` then caches the session per its TTL.
- No YubiKey present, no reads. The hardware is the access boundary, which is the point.
- If reads hang or fail with "No secret key", the card is not inserted, `gpg-agent` is not running, or `GPG_TTY` is unset. `export GPG_TTY=$(tty)` fixes the common pinentry-on-TTY case.

## Git sync

The store is a git repo, so history and sync come free:

```sh
pass git remote add origin <private-remote>      # a PRIVATE remote only
pass git push
```

Entries are encrypted at rest, so a private remote is defensible. Keep it private regardless: filenames (entry paths) and git metadata are not encrypted and leak structure. This is distinct from the offline keyvault (GPG-0006), which holds raw key material and never gets a remote.

## Pitfalls

| Symptom | Cause / fix |
| --- | --- |
| Secret ended up in shell history | Passed as argv. Use the stdin-pipe forms above. |
| `pass show` hangs | pinentry needs a TTY. `export GPG_TTY=$(tty)`, ensure `gpg-agent` is up. |
| "No secret key" / "decryption failed" | YubiKey not inserted, or store encrypted to a different gpg-id. `pass init <id>` to re-encrypt. |
| `pass otp` not found | The pass-otp extension is required (installed here at `/opt/homebrew/lib/password-store/extensions/otp.bash`). |
| Clipboard still holds a password | It clears after 45s; for sensitive haste, `pbcopy </dev/null` to clear immediately. |
