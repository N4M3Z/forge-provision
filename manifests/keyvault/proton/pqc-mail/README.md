# Decrypting this key

`address-key.asc` is a Proton post-quantum mail key: OpenPGP **v6** with ML-KEM/ML-DSA hybrid algorithms. **GnuPG cannot read it** and structurally never will (it rejects v6 packets and ships a competing LibrePGP post-quantum format). See forge-provision `docs/decisions/GPG-0007`.

Use a v6-capable implementation instead:

- **Sequoia** — the pinned `sq` binary in `../../tools/` (see `tools/README.md` to rebuild if it no longer runs).
- **Proton's own libraries** — gopenpgp / OpenPGP.js, if you still have Proton tooling.

General shape (verify flags against your `sq` version — the CLI drifts between releases, run `sq decrypt --help`):

```sh
sq --version                                   # confirm v6 + PQC support
sq decrypt --recipient-file address-key.asc  <ciphertext.pgp>  > plaintext
```

`<ciphertext.pgp>` is whatever Proton mail you exported to decrypt off-platform. This key is break-glass only: normally Proton's own apps decrypt your mail. The everyday path is the recovery material in `../recovery/`, not this key.
