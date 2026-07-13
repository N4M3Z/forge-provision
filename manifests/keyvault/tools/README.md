# Restore toolchain

The tools to restore this vault, pinned. Homebrew binaries are dynamically linked and may not launch on a future OS, so `bin/` is best-effort; the durable layer is the source in `src/` (rebuilds against whatever libraries exist then), and the SHA-256 manifest below verifies whatever you recover.

- **sq** — restores the Proton v6 post-quantum key (GPG-0007). Niche and v6-only: the one tool with genuinely uncertain future availability. Rebuild: `cargo install sequoia-sq --version <ver>`.
- **gpg** — restores the classical Curve25519 master and the pass entries. A suite (gpg, gpg-agent, scdaemon), so its real pin is the source. Rebuild: gnupg.org. The v4 master is also readable by `sq`, so it survives even a gpg-less future.
- **paperkey** — reconstructs the master from the printed paper. Its format is hand-reconstructable without the tool (GPG-0006). Source: github.com/dmshaw/paperkey.
- **qrencode** — made the QR codes; restore itself needs only `base64 -d` (coreutils). Source: fukuchi.org/works/qrencode.

## Versions and integrity

Versions that produced these backups, and the SHA-256 of every pinned artifact in `bin/` and `src/`. Verify any recovered file against this before trusting or running it.

```text
<fill in: sq --version; gpg --version; paperkey --version; qrencode --version>

<fill in: shasum -a 256 bin/* src/*>
```
