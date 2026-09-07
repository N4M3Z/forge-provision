# Recover an interrupted OpenPGP ceremony

Preserve the encrypted DMG and any migration directory. Do not delete a saved
image, reset an application, guess a PIN, or overwrite a populated slot to retry.

## PIN change failed

A failed OpenPGP PIN change normally leaves the current PIN unchanged and
decrements its retry counter. Confirm what happened from the local prompt. If
you know the current PIN, resume with the same identity and path arguments:

```sh
bash scripts/configure/openpgp-yubikey.sh --resume
```

For a recorded interrupted change, choose `1` to retry using the known current
PIN, or `2` only if the change already succeeded. These are OpenPGP credentials,
separate from PIV and macOS. If you do not know the PIN or see a blocked counter,
stop for manual recovery; the helper does not reset retry counters.

## Setup stopped around keytocard

Resume checks saved identity, device, recovery exports and PIV certificates. It
accepts only empty OpenPGP slots or fingerprints matching the saved S/E/A
subkeys. It prints the missing transfers before entering `gpg>` again. Do not
repeat transfers into already populated slots or select the primary key.

If all transfers succeeded, resume can continue with touch policies and final
verification. Public files are published atomically and only reused when their
contents match; conflicting output is preserved for inspection.

## Failure before recovery exports completed

Automatic resume starts only after all recovery exports were saved. Earlier
failures require inspection inside the original encrypted image. Preserve any
generation keyring and partial exports. Do not start a fresh identity over the
same image or treat incomplete exports as a verified backup.

## The volume stayed mounted

The helper stops its own GPG agents and attempts to unmount tracked volumes on
success, error, Ctrl+C, SIGHUP and SIGTERM. SIGKILL, power loss or busy files can
prevent cleanup. Inspect `hdiutil info` locally, close terminals and applications
using the volume, and unmount the exact reported mountpoint:

```sh
hdiutil detach '/Volumes/OpenPGP Vault'
```

Use your chosen mountpoint if it differs. Do not force-detach or upload the image
while it is mounted. In offline mode, keep networking disconnected until cleanup
is complete. Native output and result reports can identify you and your card;
redact them before sharing even though they do not contain secret keys.

## PIV inventory differs or login fails

Stop and preserve the reports. A certificate difference is not an instruction to
repair or reset PIV automatically. Conversely, unchanged certificates do not
prove the macOS pairing, PIN policy or private-key operation works. Test login
with the expected card and investigate macOS smartcard/PC/SC state independently.

For password migration failures, follow the separate
[migration recovery instructions](password-store-migration.md#recover-a-staged-run).
