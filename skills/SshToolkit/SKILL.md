---
name: SshToolkit
version: 0.1.0
description: "SSH configuration best practices: ~/.ssh/config Host blocks, FIDO2 hardware keys (ed25519-sk resident), Apple's ssh-agent vs Homebrew's openssh, ssh-add and SSH_AUTH_SOCK, ProxyJump and ProxyCommand, ControlMaster multiplexing, per-host identity selection, known_hosts hardening, SSH_ASKPASS env propagation across GUI-spawned processes. USE WHEN editing ~/.ssh/config, generating or rotating SSH keys, setting up FIDO2 resident keys, debugging agent / askpass issues, configuring jump hosts, or routing GitHub work-vs-personal identities."
sources:
    - https://man.openbsd.org/ssh_config
    - https://man.openbsd.org/ssh-keygen
    - https://man.openbsd.org/ssh-agent
    - https://developers.yubico.com/SSH/Securing_git_with_SSH_and_FIDO2.html
    - https://docs.github.com/en/authentication/connecting-to-github-with-ssh
    - https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification
---

# SshToolkit

Best-practice ssh setup. Hardware-resident FIDO2 keys, modern crypto defaults, identity routing for work-vs-personal repos, connection multiplexing, and the macOS-specific ssh-agent + ssh-askpass plumbing.

For git commit signing specifically — including the wrapper that bypasses Apple's launchd ssh-agent — see [forge-core skills/VersionControl/CommitSigning.md](https://github.com/N4M3Z/forge-core/blob/main/skills/VersionControl/CommitSigning.md). This skill covers the broader ssh stack.

## ~/.ssh/config skeleton

```ssh
# Modular config — split by concern.
Include ~/.ssh/config.d/*

# Global defaults at the bottom (Match patterns above win).
Host *
    AddKeysToAgent yes
    UseKeychain yes                          # macOS Keychain for non-SK keys' passphrases
    IdentitiesOnly yes                       # never offer all loaded keys to every host
    IdentityFile ~/.ssh/yubikey              # default FIDO2 key
    HashKnownHosts yes
    StrictHostKeyChecking accept-new         # auto-add on first connect, error on mismatch
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/control-%C
    ControlPersist 10m
    KexAlgorithms curve25519-sha256@libssh.org,curve25519-sha256,diffie-hellman-group16-sha512
    HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
```

`Include ~/.ssh/config.d/*` lets per-machine or per-org configs live in separate files (chezmoi-friendly: each file in `dot_ssh/config.d/` deploys independently).

`Host *` is a catch-all; place it last because the first matching `Host` block wins for any setting that isn't overridden by a later block (ssh has "first match" semantics for most directives, "all match" for `IdentityFile`).

## Per-host identity routing

Common patterns:

```ssh
# Work GitHub identity
Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/yubikey_work
    IdentitiesOnly yes

# Personal GitHub identity (default — covered by Host *)
Host github.com
    User git
    IdentityFile ~/.ssh/yubikey
    IdentitiesOnly yes

# Cloned with: git clone git@github.com-work:org/repo.git
# (the suffix matches Host github.com-work, picking the work identity)
```

The hostname-suffix trick is how git clones route to alternate identities without per-repo config. ssh resolves the alternate name to `github.com` via `HostName`, but selects the right key based on the matched `Host` block.

`IdentitiesOnly yes` is load-bearing: without it, ssh offers every loaded key in the agent until one is accepted, which causes "too many authentication failures" against GitHub when you have multiple keys.

## Jump hosts (ProxyJump)

```ssh
Host private-server
    HostName 10.0.1.5
    User deploy
    ProxyJump bastion.example.com

Host bastion.example.com
    User jumpuser
    IdentityFile ~/.ssh/yubikey
```

`ProxyJump` is the modern, simple form. The legacy `ProxyCommand ssh -W %h:%p bastion` form still works but is verbose and pre-dates `ProxyJump`. Use `ProxyJump` unless you need a tool other than ssh in the proxy (rare; `ProxyCommand` is for custom proxies).

Multi-hop:

```ssh
Host innermost
    ProxyJump bastion1,bastion2
```

ssh chains the jumps in order. Each hop reuses ControlMaster multiplexing if configured.

## FIDO2 hardware-resident keys (ed25519-sk)

Why resident: the credential can be re-imported on another machine with `ssh-keygen -K` from the same YubiKey. Non-resident `ed25519-sk` keys lose their handle when the `.pub` file is gone.

Generate via `scripts/install/ssh-yubikey-key.sh`. The script enforces:

```sh
ssh-keygen \
    -t ed25519-sk \
    -O resident \
    -O verify-required \                 # require PIN + touch every use
    -O application="ssh:<identifier>" \  # disambiguates multiple resident keys
    -C "<email>" \
    -f ~/.ssh/yubikey
```

The `application=` field is the FIDO2 RP-ID equivalent — it lets one YubiKey hold multiple resident SSH credentials without colliding. Use `ssh:<github-user>` or similar.

**Apple's `/usr/bin/ssh-keygen` knows the algorithm but lacks the libsk-libfido2 wrapper.** Homebrew's `/opt/homebrew/bin/ssh-keygen` has it. Always invoke the brew binary explicitly when generating or signing with FIDO2 keys. The brew openssh formula pulls libfido2 as a dependency.

### Re-importing on a fresh machine

```sh
ssh-add -K                                   # imports all resident keys to ssh-agent
ls ~/.ssh/                                   # the public + handle files reappear
```

The handle files (`yubikey`, `yubikey.pub`) are regenerated from the YubiKey state. No need to back up `~/.ssh/yubikey*` — the YubiKey is the backup.

## Apple's ssh-agent vs Homebrew's openssh

macOS launchd ships a stub `ssh-agent` (socket exported via `SSH_AUTH_SOCK=/var/run/com.apple.launchd.*/Listeners`) that lacks libfido2 middleware. It works for regular keys (loaded via `ssh-add`); it **refuses** FIDO2 keys with "agent refused operation".

| Use case                                  | Apple ssh-agent | Homebrew openssh |
| ----------------------------------------- | --------------- | ----------------- |
| Loading non-SK keys with passphrase        | YES (Keychain integration) | YES (no Keychain) |
| Auth with `ed25519-sk` over ssh           | NO              | YES               |
| Signing git commits with `ed25519-sk`      | NO              | YES (via wrapper, see CommitSigning) |
| `ssh-add -K` to import resident keys      | partial          | YES               |

The pragmatic split: keep Apple's ssh-agent for Keychain-cached non-SK keys, use Homebrew's `ssh-keygen` for FIDO2 signing via the `git-ssh-sign-macos` wrapper. Don't try to replace one with the other — both can coexist via the `SSH_AUTH_SOCK` indirection.

## SSH_ASKPASS env propagation

`SSH_ASKPASS` points to a GUI program ssh invokes when it needs a passphrase or PIN and stdin isn't a TTY. `theseal/ssh-askpass/ssh-askpass` is the canonical macOS Cocoa askpass.

The trap: most setups export `SSH_ASKPASS` from `~/.zshenv` — which only loads for zsh-spawned processes. GUI-launched apps (IDEs, Spotlight launches, Finder open) inherit launchd's environment and miss `SSH_ASKPASS`. Symptom: ssh hangs waiting on TTY, or signing fails with "agent refused operation" without surfacing a dialog.

Two fixes:

1. **Launch from terminal**: `open -a "AppName" .` so the app inherits the zsh env.
2. **Export via launchd** so every process sees it:
   ```sh
   launchctl setenv SSH_ASKPASS /opt/homebrew/bin/ssh-askpass
   launchctl setenv SSH_ASKPASS_REQUIRE force
   ```
   Survives until reboot; persist via a `LaunchAgent` plist for every boot. `SSH_ASKPASS_REQUIRE=force` makes ssh always try the GUI prompt instead of waiting on TTY.

## ControlMaster multiplexing

```ssh
Host *
    ControlMaster auto
    ControlPath ~/.ssh/control-%C
    ControlPersist 10m
```

`ControlMaster auto` reuses a single TCP/SSH connection for subsequent ssh / scp / sftp sessions to the same host. First connection negotiates; subsequent ones piggyback (instant connect, no re-auth). `ControlPersist 10m` keeps the multiplexed connection alive 10 minutes after the last client disconnects.

`%C` in `ControlPath` is a SHA1 hash of host+port+user — keeps paths short and avoids collisions. Pre-create `~/.ssh/` with `chmod 700` so ssh accepts the control socket location.

Drop ControlMaster for hosts where multiplexing causes issues (rare; older OpenSSH servers, some commercial appliances). Override per-host:

```ssh
Host legacy-server
    ControlMaster no
```

## known_hosts hygiene

`HashKnownHosts yes` (in the global block above) writes hashed hostnames so a leaked `known_hosts` doesn't enumerate the hosts you connect to. Existing unhashed entries stay unhashed; re-hash with:

```sh
ssh-keygen -H -f ~/.ssh/known_hosts          # in-place hash, .old backup
```

`StrictHostKeyChecking accept-new` auto-adds first-time hosts but errors on key mismatch (man-in-the-middle protection). Removes the manual `yes/no` prompt at first connect; still protects against tampering.

When a host key legitimately rotates (server reinstall, container migration), remove the stale entry:

```sh
ssh-keygen -R <hostname>                     # removes by hostname
ssh-keygen -R <ip-address>                   # removes by IP (separate entry)
```

## allowed_signers for git verify-commit

```sh
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
```

One entry per line in `~/.ssh/allowed_signers`:

```
your.email@example.com sk-ssh-ed25519 AAAA...your.pubkey.contents... namespace="git"
```

`namespace="git"` scopes the key to git signing only. Without `allowed_signers`, `git verify-commit` and `git log --show-signature` can't validate signatures locally. GitHub uses its own server-side allowed-signers list; this file only affects local verification.

`scripts/configure/git-signing-ssh.sh` writes `~/.config/git/allowed_signers` and points git at it (note the `.config/git/` path, an alternate location git also accepts).

## Common pitfalls

| Symptom                                                                | Cause / Fix                                                                                                          |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| "Too many authentication failures" against GitHub                       | `IdentitiesOnly yes` missing. ssh offered every loaded key, GitHub rate-limits after ~6.                              |
| Per-repo identity not picking up                                       | Cloned via plain `git@github.com:...` instead of `git@github.com-<suffix>:...`. Re-clone or `git remote set-url`.    |
| `ed25519-sk` key fails to load                                          | Using Apple's `/usr/bin/ssh-keygen`. Switch to `/opt/homebrew/bin/ssh-keygen` for FIDO2 ops.                          |
| ssh hangs forever waiting on passphrase                                | `SSH_ASKPASS` not exported in this process. Either launch from zsh terminal, or `launchctl setenv SSH_ASKPASS_REQUIRE force`. |
| `ssh-add -K` does nothing                                               | YubiKey not plugged in, or no resident credentials on the key. `ssh-keygen -K` extracts to current dir to verify.    |
| ControlMaster causes "another connection is active" error               | Stale control socket from a previous session. `rm ~/.ssh/control-*` and retry.                                       |
| known_hosts has the wrong key, ssh refuses to connect                  | Host key legitimately rotated. `ssh-keygen -R <hostname>` then reconnect to re-accept.                                |

## Provisioning order on a fresh Mac

```sh
brew install openssh                                    # via Brewfile
scripts/install/ssh-yubikey-key.sh                      # generate or import resident FIDO2 key
gh auth login                                            # interactive
gh ssh-key add ~/.ssh/yubikey.pub --title "$(hostname -s)"
gh ssh-key add ~/.ssh/yubikey.pub --type signing --title "$(hostname -s) signing"
scripts/configure/git-identity.sh                        # name, email
scripts/configure/git-signing-ssh.sh                     # gpg.format=ssh, signingkey, allowed_signers
scripts/configure/git-ssh-sign.sh                        # the macOS wrapper for FIDO2 signing
```

`chezmoi apply` lays down `~/.ssh/config`, `~/.ssh/config.d/*`, and any per-host blocks from the chezmoi source. Don't edit `~/.ssh/config` directly — edit `dotfiles/dot_ssh/config` and re-apply.

## Reload after config edit

```sh
# No reload needed — ssh re-reads ~/.ssh/config on every invocation.
# To verify the resolved config for a host:
ssh -G <hostname>                            # prints the effective config (no connection)
```

`ssh -G` is the canonical way to debug "which Host block applied" — it prints the resolved settings after all `Match`/`Host` evaluation.
