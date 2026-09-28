# 2026-07-16 Work Laptop Provisioning

First run of the full INSTALL.md flow on a managed Proton work laptop
(MDM profiles, sudo behind Duo, agent-side file-guard and sandbox policies).
`SCOPE=work` with dotfiles deployment. Driven by an agent; the operator
handled every step the policies reserved for a human.

## What worked

- The work-scope run itself: install, configure, verify, with every
  personal-lane script self-skipping on `skip:… (personal scope; SCOPE=work)`.
- `verify` converged to green except cask entries owned by MDM.

## What failed, and the fixes that came out of it

- **Agent blocked from writing `.env`**: the file-guard hook denies `*.env`
  by design. The agent staged the content under an allowlisted name and the
  operator copied it into place. Documented in INSTALL.md.
- **Bundle failures on a managed machine**: root-owned MDM apps (Claude,
  Yubico Authenticator, Google Chrome) and the Teams pkg installer need sudo,
  which a headless run cannot prompt for. `brew-bundle.sh` now warns upfront
  when it runs headless without cached sudo. Teams moved to the new opt-in
  `manifests/Brewfile.microsoft` together with the Office mas block.
- **Tap trust on a migrated machine**: Homebrew 6 refused the previously
  installed `pass-cli` from the untrusted `protonpass/tap`, failing the
  bundle entry for the unrelated homebrew-core `proton-pass-cli`.
  `brew trust protonpass/tap` resolved it. Documented in INSTALL.md.
- **YubiKey PIN attempts consumed headlessly**: `ssh-yubikey-key.sh` ran
  unattended, ssh-keygen prompted into empty stdin, and two FIDO2 PIN retry
  attempts were consumed (the counter recovered). The script now skips
  itself without an interactive terminal.
- **Private dotfiles unreachable from the agent shell**: the hardened agent
  sandbox denies git-spawned credential helpers access to `~/.config/gh`
  even though direct `gh` calls work. `dotfiles.sh` now names the operator
  hand-off instead of guessing at `gh auth login`.

## Dotfiles bugs found by a blank machine

Fixed in the dotfiles repo, discovered here because this was the first
apply against a machine with no live configs:

- Bash comments containing a literal chezmoi include directive rendered as a
  zero-argument template call and crashed `chezmoi apply`.
- The policy-merge modify scripts crashed merging into a live config that
  does not exist yet; the pipelines now default absent input to `{}`.
- A partial apply is order-sensitive: `.claude/settings.json` landed before
  the `~/.local/bin` scripts its hooks reference, leaving hook errors until
  the apply completed.
