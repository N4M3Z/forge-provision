# SSH

Public keys and config to reconstruct the SSH setup. The YubiKey FIDO2 keys are hardware-bound: the private credential never leaves the card, so a `*_sk` handle here is useless without the YubiKey and is re-downloadable from a resident key with `ssh-keygen -K`. Any on-disk (non-hardware) private keys are real secrets and belong here too.

- `*.pub`: public keys, for re-registering with GitHub and others
- `config`: which `IdentityFile` maps to which host and key
- `yubikey_*`: FIDO2 key handles (need the physical YubiKey to use)
