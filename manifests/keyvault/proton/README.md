# Proton

- `recovery/` — account recovery phrase and key. These reset the Proton password and unlock Mail, Drive, Pass, Calendar when all else is lost. Kept here so they survive even if Proton access is lost — which is why this vault must also live offline, not only on Proton Drive.
- `pqc-mail/` — a post-quantum address-key export. Break-glass only; GnuPG cannot read it (see that folder).

Day to day, Proton's own apps handle decryption. This directory is the floor under that.
