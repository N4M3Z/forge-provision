---
title: Git author identity
description: Global git author is `Martin Zeman <N4M3Z@users.noreply.github.com>` for GitHub-hosted repos. Non-GitHub repos override per-repo with a forge-specific alias on the personal domain (e.g., `gitlab@martinzeman.net`). Distinct from signing (covered by ARCH-0006).
type: adr
category: governance
tags:
    - git
    - identity
    - privacy
    - github
    - forge
status: accepted
created: 2026-05-30
updated: 2026-05-30
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0006 Commit signing.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream:
    - https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/setting-your-commit-email-address
---

# Git author identity

## Context and Problem Statement

Every git commit records an author name and email. These are independent of who signed the commit ([ARCH-0006][6] covers signing). The author fields drive how commits are attributed in `git log`, in the hosting platform's UI, in commit-author search, and in tools that map authorship to identity (CODEOWNERS, blame heatmaps, contribution analytics).

A provisioning script that writes the global git config must capture both name and email correctly. Getting either wrong has consequences: a nickname obscures recognition; a real email leaks into public history forever. Different forges (GitHub, GitLab, Codeberg, self-hosted) also offer different attribution mechanics, which makes a single global value sub-optimal for projects hosted off GitHub.

## Decision Drivers

- The displayed author name should match the hosting platform's profile display ("Martin Zeman"), so commits read consistently across `git log` and forge UIs
- The author email must not place the real Proton address into public git history
- `scripts/configure/git-identity.sh` reproduces the values on a fresh Mac, so `.env` is the source of truth for the global default
- Per-repo overrides are inexpensive and survive across machines via the repo's `.git/config`, so per-forge customization should use that mechanism rather than a more complex global scheme
- The identity must work for both GPG-signed and SSH-signed commits ([ARCH-0006][6])

## Considered Options

1. **Real name + real email globally** (the personal Proton address). Maximum recognizability but leaks the address into public history.
2. **Nickname + GitHub noreply globally** (`N4M3Z <N4M3Z@users.noreply.github.com>`). Privacy preserved but the displayed name is the handle, not the person.
3. **Real name + GitHub noreply globally** (`Martin Zeman <N4M3Z@users.noreply.github.com>`). Real name for recognition; noreply alias keeps the Proton address private and maps to the GitHub account automatically. Sub-optimal for non-GitHub forges where the noreply does not auto-map.
4. **Real name + personal-domain alias globally** (`Martin Zeman <github@martinzeman.net>`). Custom alias on an owned domain; portable across forges; can be disabled if compromised. Reveals domain ownership; commits orphan if the domain is lost or the alias is disabled without rotating.
5. **Per-forge: GitHub noreply globally + per-repo alias on personal domain elsewhere.** GitHub repos use the noreply automatically. Non-GitHub repos override locally with a forge-specific alias (e.g., `gitlab@martinzeman.net`). Combines the privacy benefit of the noreply where it works with the portability benefit of the personal-domain alias where it does not.

## Decision Outcome

Chosen option: **per-forge — option 5**.

### Global default (GitHub-hosted repos)

Source of truth lives in `.env`:

```sh
GIT_NAME="Martin Zeman"
GIT_EMAIL="N4M3Z@users.noreply.github.com"
```

`scripts/configure/git-identity.sh` reads these and applies them to the global git config. The script is idempotent and safe to re-run.

### Per-repo override (non-GitHub forges)

For a repo hosted on a non-GitHub forge, set a per-repo email at clone time:

```sh
git -C <repo> config --local user.email "gitlab@martinzeman.net"
```

Naming convention for forge-specific aliases on `martinzeman.net`:

| Forge | Alias |
| ----- | ----- |
| GitLab (gitlab.com, self-hosted) | `gitlab@martinzeman.net` |
| Codeberg | `codeberg@martinzeman.net` |
| Bitbucket | `bitbucket@martinzeman.net` |
| Self-hosted Gitea/Forgejo | `gitea@martinzeman.net` |

Each alias is a forwarder on the personal domain. The forge's profile must list the alias as a verified email for the commits to attribute to the account.

The user-name stays `Martin Zeman` in every case. Only the email varies per forge.

### Drift recovery (global)

If a commit on `main` of a GitHub repo shows the wrong author (typically because the global config was changed locally without re-running the provisioning script):

1. Fix `.env` so it carries the correct values.
2. Re-run `scripts/configure/git-identity.sh` to apply the fix to the global git config.
3. For the immediately preceding commit, amend with `git commit --amend --reset-author --no-edit` (re-signs via the YubiKey path from [ARCH-0006][6]).
4. Force-push with `git push --force-with-lease`. Never plain `--force`.
5. Older drift commits stay as-is — rewriting deeper history is not worth the rebase blast radius for what is a display issue.

### Signing identity vs author identity

These are independent. The signing key's registered email on the hosting platform appears in `git log --show-signature` output as the signing identity. The author email appears in the commit's author field. Both are correct; both serve different purposes.

### Consequences

- [+] Commits read consistently as `Martin Zeman` across local tooling, every forge's UI, and contribution analytics
- [+] The real Proton address stays out of public git history on every forge
- [+] GitHub maps the noreply alias to the account automatically — zero per-repo config in the common case
- [+] Non-GitHub forges get a portable, controllable alias on an owned domain
- [+] If the personal-domain alias is ever compromised, disable the forwarder without affecting GitHub identity
- [-] The drift recovery procedure must be run by hand when divergence is found; no automation enforces the convention between sessions
- [-] Each new non-GitHub repo requires a one-time `git config --local user.email` after clone, plus a verified-email setup on that forge
- [-] If the personal domain is ever lost, all non-GitHub commits orphan their authorship; the GitHub noreply stays safe

## More Information

- [ARCH-0006 Commit signing][6] — the signing path
- [GitHub: setting your commit email address][GH] — how the noreply alias maps to the account
- [`scripts/configure/git-identity.sh`][SCRIPT] — applies the global default to git config
- [`.env.example`][ENV] — declares the variables; live values in the gitignored `.env`

[6]: ARCH-0006%20Commit%20signing.md
[GH]: https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/setting-your-commit-email-address
[SCRIPT]: ../../scripts/configure/git-identity.sh
[ENV]: ../../.env.example
