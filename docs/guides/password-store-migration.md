# Move pass to a new OpenPGP identity

Keep the old decryption key and the new public certificate available. Keep the
old card until both current data and any historical data you need are accounted
for. Never reset it merely because the new key can read one password.

## Native pass migration

The built-in command changes recipients and re-encrypts existing entries:

```sh
pass init NEW_PRIMARY_FINGERPRINT
```

Supply only the new recipient for a replacement. Supplying both old and new IDs
encrypts to both; it is not a source/destination argument pair. `pass init -p`
targets a subtree with its own recipient configuration.
[Official pass documentation](https://git.zx2c4.com/password-store/about/).

Before running, preserve a private backup of the entire store, including `.git`,
the index and untracked files. Keep other `pass` users and synchronization idle.
Inspect nested `.gpg-id` files, signed recipient files, and environment overrides
such as `PASSWORD_STORE_DIR`, `PASSWORD_STORE_KEY` and `PASSWORD_STORE_GPG_OPTS`.
Make sure you are using the intended store and recipient configuration.

Afterward, disconnect the old card and verify reads with the new card. Checking
one entry is a useful smoke test, not proof that every entry migrated. Hidden
recipient ciphertext can show zero key IDs; packet headers alone cannot identify
the new recipient. Verify decryption, or use the optional staged helper below
for per-entry comparison before switching.

### Re-encryption and Git commits can fail separately

`pass` updates recipient configuration and processes entries individually; the
operation is not a single transaction. A failure can leave a partially migrated
store. It also creates Git commits when the store uses Git. `No secret key`,
`INV_SGNR`, or `failed to write commit object` can refer to the configured Git
signer after a ciphertext was already rewritten.
[Implementation of pass](https://git.zx2c4.com/password-store/tree/src/password-store.sh).

Inspect `.gpg-id`, entry decryptability, and `git status` independently. Correct
the repository's Git signing configuration before committing verified changes.
Review the index for unrelated files such as `.DS_Store`; avoid blanket staging.
Do not assume a failed commit rolled back the encryption, or that an updated
`.gpg-id` proves every entry is new-key-only.

Old ciphertext in Git history and backups still requires the old secret key.
Migration does not rewrite history or revoke the old identity.

## Optional staged migration helper

Use this for a single-recipient, self-contained Git-backed store when you want
every entry compared before replacing the live directory. It supports two
distinct OpenPGP cards with known full primary/encryption fingerprints and
application IDs. It refuses symlinks, special files, Git lockfiles, nested or
signed recipients, Git object alternates, and unexpected environment overrides.

The helper copies the whole store, preserving Git history, index and untracked
files. For each entry it decrypts the original with the selected old subkey,
encrypts the staged copy to the selected new subkey, decrypts it using the new
card and compares the bytes in memory. Password bytes are never deliberately
written to a temporary file or log; Python and GnuPG still handle them in process
memory. Core dumps are disabled, but this is not a locked-memory guarantee.

Verified ciphertext and progress are flushed before checkpointing. The live
store stays unchanged until a new-card-only `pass` smoke test and final inventory
checks pass. Activation uses a journaled pair of directory renames with an exact
rollback copy; it is not an atomic multi-directory transaction. Keep the store
idle throughout. The helper does not commit or push.

### Configure locally

Save a private JSON file **outside this checkout**. Replace every placeholder;
the fingerprint values must each be 40 hexadecimal characters. `old_card` and
`new_card` are full 32-character OpenPGP application IDs from GnuPG metadata,
whereas `new_serial` is the decimal serial from `ykman list --serials`.

```json
{
  "old_primary": "OLD_PRIMARY_FINGERPRINT",
  "old_encryption": "OLD_ENCRYPTION_SUBKEY_FINGERPRINT",
  "old_card": "OLD_OPENPGP_APPLICATION_ID",
  "new_primary": "NEW_PRIMARY_FINGERPRINT",
  "new_encryption": "NEW_ENCRYPTION_SUBKEY_FINGERPRINT",
  "new_card": "NEW_OPENPGP_APPLICATION_ID",
  "new_serial": "NEW_DECIMAL_SERIAL",
  "public_certificate": "~/.local/share/keyvaults/openpgp-public/openpgp-public.asc"
}
```

Optional path fields are `source` (default `~/.password-store`), `gpg_home`
(`~/.gnupg`), `vaults` (`~/.local/share/keyvaults`) and `output_dir`
(`~/.local/share/keyvaults/openpgp-public`). Use a staging parent on the same
filesystem as the source, outside the store. Saved runs include normalized
configuration in a separate preparation baseline. Resume checks its private
directory, journal schema, relative paths and agreement with that baseline before
using any entry path. These checks detect damaged progress files; they do not
authenticate files against an attacker who can rewrite the entire private run.

```sh
bash scripts/migrate/password-store.sh prepare --config /private/path/migration.json --dry-run
bash scripts/migrate/password-store.sh prepare --config /private/path/migration.json
```

Record the printed migration-directory path as `RUN` locally. Connect both cards:

```sh
bash scripts/migrate/password-store.sh prepare-key "$RUN"
bash scripts/migrate/password-store.sh finish "$RUN"
```

`prepare-key` verifies the supplied certificate's primary and encryption subkey,
backs up ownertrust, imports the public certificate, sets own-key ultimate trust,
and checks both encryption subkeys' card references. Only use this configuration
for your own new identity. `finish` resumes verified entries, then asks you to
unplug the old card before the normal `pass` test and switch.

For hidden recipients, `finish` adds a `try-secret-key` preference for the new
encryption subkey to the selected GPG home's `gpg.conf`. It records and backs up
the previous contents. On a pre-activation failure it restores only its exact
edit, preserving concurrent changes. Signing and PIV configuration are untouched.

### Recover a staged run

Rerun `finish "$RUN"` after resolving a known PIN, touch timeout or device access
problem. It skips only journaled, unchanged ciphertext. If the live source changed
since preparation, it stops rather than replacing newer data. Do not combine a
saved staging run with an intervening native `pass init`; that invalidates the
original baseline.

If interrupted during activation, the helper reconciles exact directory states
against the saved manifests. It either recognizes the completed switch or
restores the original directory before continuing. Ambiguous or modified states
require manual inspection. Preserve `baseline.json`, `state.json`, `staged-store`, `original-store`
and any GPG config backup; never overwrite them to force a resume.

The result report distinguishes full per-entry comparisons from the one-entry
normal `pass` smoke test. Keep the rollback store and old decryption key until
you have separately decided how to retain historical ciphertext.
