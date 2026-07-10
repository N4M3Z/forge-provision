# Proton Pass CLI (pass-cli)

Proton's **official** command-line client for Proton Pass. Open source (GPL-3.0, Rust), docs `protonpass.github.io/pass-cli`. A different tool from the password-store `pass`: different binary (`pass-cli`), different store (your E2EE Proton Pass vaults). Requires a paid Pass plan (Plus / Family / Professional / bundle); the free tier is excluded. Surface below verified against `pass-cli` 2.1.4.

## Install

```sh
brew install proton-pass-cli                   # official, in homebrew-core
# alternative: the SHA256-verified installer
curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
```

The Homebrew formula is `proton-pass-cli`; it installs the `pass-cli` binary (depends on `openssl@3`). Not on npm or cargo. macOS (x86_64/arm64), Linux, Windows. Self-update with `pass-cli update`.

## Authentication

```sh
pass-cli login                       # default: web login (browser handoff)
pass-cli login --interactive <user>  # terminal username/password (+ 2FA)
pass-cli test                        # check the authenticated connection
pass-cli info                        # show the current session
```

Non-interactive / CI uses a **scoped personal access token** (format `pst_<token>::<key>`), which makes scripted use legitimate without driving a full interactive login:

```sh
pass-cli personal-access-token create        # mint a PAT (also: list, renew, delete, access)
pass-cli login --pat 'pst_<token>::<key>'    # authenticate with it
```

Keep the PAT itself in `pass` or another secret store, never in a tracked file, and scope it to the minimum vault it needs.

## Listing and reading

```sh
pass-cli vault list                  # enumerate vaults
pass-cli item list                   # list items (scope to a vault as needed)
pass-cli item view <item>            # read an item's fields
pass-cli totp generate <item>        # current TOTP code from a stored secret / URI
```

`item` also offers `create`, `delete`, `move`, `share`, and `attachment`.

## Injecting secrets (keep plaintext out of argv and logs)

Prefer reference-based injection over copy-paste, so the secret never lands in your shell history or a log:

```sh
pass-cli run -- <command>                       # resolve secret refs into the child env, then exec
pass-cli run --env-file <tpl> -- <command>      # with a dotenv template
pass-cli inject -i <template> -o <out-file>     # fill a template file (output mode 0600 by default)
```

`run` masks secrets on stdout/stderr by default (`--no-masking` disables). Secret references use the documented `pass://<vault>/<item>/<field>` form; confirm the exact token syntax with `pass-cli help inject` before relying on it.

## SSH agent

`pass-cli` can act as an SSH agent backed by Pass-stored keys, the nearest thing Pass has to a Proton Bridge daemon (there is no IMAP/SMTP-style bridge for Pass):

```sh
pass-cli ssh-agent ...               # see `pass-cli ssh-agent --help` for the subcommands
```

## Export (the non-CLI path)

Proton Pass exports are a GUI action (browser extension / web / Windows app, not mobile): unencrypted CSV, unencrypted JSON, or PGP-encrypted JSON in a ZIP. The PGP export decrypts with `gpg --decrypt`. Treat export as a manual backup, not a programmatic interface; for scripted access the CLI is the sanctioned path.

## Unofficial fallback

`github.com/roman-16/proton-cli` (Go, MIT) is a community client covering Mail, Drive, Calendar, Contacts, and Pass, authenticating via SRP + 2FA like the web client. It is **unofficial and not endorsed by Proton**. Use it only for Proton services `pass-cli` does not cover, never as the primary Pass tool, and weigh that it scripts your full Proton credentials rather than a scoped token.

## Pitfalls

| Symptom | Cause / fix |
| --- | --- |
| Commands fail with no vault access | Free tier, or the PAT is scoped too narrowly. Pass CLI needs a paid plan; widen the token scope. |
| Secret visible in CI logs | Used a print path instead of `run` / `inject`. Reference the secret so plaintext never lands in the log; `run` masks by default. |
| Confused with the password-store | `pass` and `pass-cli` are different tools. This file is only the Proton one. |
