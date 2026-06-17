# YubiKey fleet

Non-secret inventory of the physical cards. **Never record PINs here.** If you always have the forge-provision repo, this file is redundant with PROV-0003 / ARCH-0006 and can be deleted.

## Shared configuration

- **OpenPGP key:** `${KEYID}` (same Curve25519 key on every card via keytocard)
- **Touch policy:** `on` for signature, encryption, authentication (a touch per operation)
- **Signature PIN (`forcesig`):** off, one PIN per card insertion, not per signature
- **KDF:** off (the applet rejects `kdf-setup` once keys are loaded; would require `ykman openpgp reset` + re-provision to enable)
- **Firmware:** 5.7.4 (EUCLEAK-safe; no field firmware update)

## Applet roles (per ARCH-0006, PROV-0003)

- **OpenPGP:** GPG commit signing, decryption, authentication
- **FIDO2:** git SSH signing (`yubikey_5c_nano_2026`) and Proton account 2FA
- **PIV:** macOS login (sudo uses Touch ID, not the card)

## Cards

| Name (PROV-0003)       | Serial                  | Notes                         |
| ---------------------- | ----------------------- | ----------------------------- |
| `yubikey_5c_nano_2026` | `<fill in: ykman info>` | primary                       |
| `<second card>`        | `<fill in>`             | backup, provision identically |
