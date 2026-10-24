# 2026-09-07 — Resumable OpenPGP provisioning

Added opt-in `scripts/configure/openpgp-yubikey.sh` and
`scripts/migrate/password-store.sh`, backed by Python helpers and isolated tests.
Ordinary provisioning skips both ceremonies. Identities, paths and device
bindings come from operator configuration; runtime key material and reports
belong outside the repository.

The setup workflow verifies encrypted recovery exports before interactive S/E/A
transfers, journals PIN and touch-policy progress, preserves existing PIV
certificate inventories and unmounts its vault on cleanup. It explains numbered
resume choices and prints the transfer guide before entering GnuPG. Network
bypass is explicit per run.

The staged migration verifies every password before activation, preserves the
entire original store, detects concurrent changes and reconciles interrupted
renames. The guide also documents the simpler native `pass init` route and the
distinction between re-encryption failures and automatic Git commit failures.

Documented PIV 9A versus 9D, separate macOS login verification, scoped Git/SSH
identities, hidden recipients, historical-key retention and terminal SSH wrappers
that can trigger an additional authentication. See the
[OpenPGP guide](../guides/openpgp-yubikey.md) and run `make test-openpgp` for
hardware-free regression coverage.
