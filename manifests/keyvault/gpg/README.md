# GPG key material

One directory per key, named by key ID. Each holds:

- `key.asc`: full secret key (master + subkeys), passphrase-protected
- `subkeys.key.asc`: secret subkeys only (laptop-grade restore, master stays offline)
- `cert.asc`: public certificate (not secret; needed for paperkey reconstruction)
- `paperkey.txt`, `paperkey-qr.png`: digital twins of the printed paper backup

Restore: `gpg --import key.asc`. The passphrase is still required to use the key. The revocation certificate is deliberately **not** here: it is printed and stored separately.

Obsolete keys are archived here too, each in its own `0x<oldkeyid>/` directory, then removed from the working tree but kept in git history (this volume is a git repo, GPG-0006).

## Verify (paperkey roundtrip)

Prove the paper backup reconstructs the master, in a throwaway keyring that never touches your real one or the card. Run from a key's directory (`gpg/<keyid>/`).

Digital backup (run this to confirm the backup bytes before trusting the workflow):

```sh
export GNUPGHOME=$(mktemp -d)
gpg --import cert.asc
paperkey --pubring cert.asc --secrets paperkey.txt | gpg --import
gpg --list-secret-keys --keyid-format 0xlong     # fingerprint must match the master
echo roundtrip | gpg --clearsign                 # signs only if the secret is intact
rm -rf "$GNUPGHOME"; unset GNUPGHOME
```

Printed QR (the real test, run after printing to confirm the paper survived):

```sh
export GNUPGHOME=$(mktemp -d)
gpg --import cert.asc
base64 -d scanned-qr.txt > "$GNUPGHOME/pk.raw"   # scanned-qr.txt = the QR scanned back in
paperkey --pubring cert.asc --secrets "$GNUPGHOME/pk.raw" | gpg --import
gpg --list-secret-keys --keyid-format 0xlong     # same fingerprint + clearsign checks
echo roundtrip | gpg --clearsign
rm -rf "$GNUPGHOME"; unset GNUPGHOME             # also removes the reconstructed pk.raw
```

A CRC mismatch or a wrong fingerprint fails loudly: reprint or re-scan.
