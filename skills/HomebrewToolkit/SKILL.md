---
name: HomebrewToolkit
version: 0.1.0
description: "Homebrew best practices: bottle vs cask vs mas (when to use each), Brewfile authorship (grouping, tombstones for intentionally-excluded apps, Brewfile.optional split for evaluation installs), destruction semantics (brew uninstall removes the .app), tap management, pinning. USE WHEN authoring or editing a Brewfile, debugging brew install/upgrade behavior, choosing between brew and mas and manual install, adding a third-party tap, or detaching Homebrew from a cask without losing the app."
sources:
    - https://docs.brew.sh
    - https://docs.brew.sh/Manpage
    - https://docs.brew.sh/Cask-Cookbook
    - https://github.com/Homebrew/homebrew-bundle
    - https://github.com/mas-cli/mas
    - https://docs.brew.sh/Taps
---

# HomebrewToolkit

Homebrew is the macOS package manager: bottle / cask / mas under one Brewfile. This skill is the best-practice playbook for using brew without surprises — especially the destruction semantics of `brew uninstall --cask` that catch people the first time.

## Bottle vs cask vs mas

| Channel  | What it ships                                              | Install path                       | Update mechanism                              |
| -------- | ---------------------------------------------------------- | ---------------------------------- | --------------------------------------------- |
| `brew "<name>"` (bottle) | CLI tools, libraries, daemons                | `/opt/homebrew/{bin,lib,Cellar}`   | `brew upgrade <name>`                         |
| `cask "<name>"` (cask)   | GUI .app bundles (and some CLIs in disguise) | `/Applications/<name>.app`         | `brew upgrade --cask <name>` (often unattended-unsafe) |
| `mas "<name>", id: <N>` | Mac App Store apps (entitlement-bound)        | `/Applications/<name>.app`         | App Store's own update path                   |

**Pick a channel by the constraint, not the convenience**:

- **Bottle** for CLI tools — easiest to update, easiest to scope-limit (`brew leaves`, `brew uses`). Most things land here.
- **Cask** for GUI apps where you trust the upstream's release cadence and want unattended `brew upgrade` to apply updates. NOT for apps that ship breaking changes weekly without semver discipline (see "Why not cask" below).
- **mas** for App Store apps where the Apple ID purchase / entitlement is the source of truth. Requires being signed into the same Apple ID that owns / purchased the app; `mas signin` is **deprecated since macOS 10.15** — sign in via System Settings instead.

### Why not cask (for some apps)

Some rapid-ship apps ship breaking changes between releases, treat semver as decorative, or push critical hotfixes through cask faster than a human can review them. Examples in this user's setup that intentionally bypass cask:

- **cmux** — manaflow-ai/cmux. Migrated from cask to manual DMG via `scripts/install/cmux.sh` after `brew upgrade` was identified as a risk. See the Brewfile tombstone comment for the rationale.

For these, the canonical install path is a `scripts/install/<app>.sh` that curls the GitHub-canonical-latest DMG (`releases/latest/download/<asset>`) and a Brewfile tombstone comment explaining why the cask is *intentionally absent*. The tombstone is load-bearing: without it, a future session sees a missing cask and "fixes" it by adding it back.

### Why not bottle (for some tools)

Same logic in reverse. Tools whose Homebrew bottle lags behind upstream (Rust nightly, language version managers with their own self-update, polyglot dev-environment shells) install better via their own canonical installer. Document the choice with a tombstone in the same place a `brew "<name>"` would have gone.

## Brewfile authorship

A Brewfile is read by `brew bundle install --file=<path>`. Conventions that pay off long-term:

```ruby
# manifests/Brewfile — grouped by topic, every entry has a why-comment.

# Proton suite (user is a Proton co-founder — defaults to Proton-native).
cask "proton-drive"
cask "proton-mail"
cask "proton-vpn"

# Local LLM runner.
cask "lm-studio"

# AI coding agent (CLI). Configured locally with lm-studio + Proton Lumo as providers.
# Config TBD — capture as scripts/configure/opencode.sh once provider files settle.
brew "opencode"
```

Best practices:

1. **Group by topic, not channel.** Brewfile readability comes from "what cluster does this app belong to" (proton suite, dev tools, editors) not "is it a brew or a cask".
2. **Every entry has a why-comment.** A bare `brew "foo"` rots — no one remembers why `foo` was added six months later. Even `# bundled with X` is enough.
3. **Tombstone intentionally-absent apps in place.** When you remove a cask but want future sessions to NOT re-add it, leave a comment block at the entry's original sort position explaining why. Example: the `cmux` block in `manifests/Brewfile` after the `cmux` cask was migrated to manual DMG.
4. **Brewfile.optional for evaluation installs.** Apps you tried and didn't adopt as daily drivers (Warp, Wave) live in `manifests/Brewfile.optional`. Same `brew bundle install --file=...` invocation, separate file. Keeps the primary Brewfile lean while preserving the evaluation history.
5. **Reference taps explicitly.** When a tap is needed, add the `tap "<owner>/<repo>"` line near the dependent entries, not at the top. Grouping the tap with its consumers makes the dependency visible.

## Tap management

```sh
brew tap                                # list active taps
brew tap-info <owner>/<repo>            # inspect a tap
brew tap <owner>/<repo>                 # add a tap
brew untap <owner>/<repo>               # remove (formulae from this tap become unmanaged)
```

**When to host your own tap**: if you ship 2+ formulae and want a single place to publish them, a tap is cheaper than maintaining a homebrew-core PR. A tap is just a git repo with `Formula/*.rb` or `Casks/*.rb`. Naming convention: `<owner>/homebrew-<name>`; users add it as `brew tap <owner>/<name>` (the `homebrew-` prefix is implicit).

**Tap stability concerns**: third-party taps disappear, lag upstream, or go dormant. Pin the tap to a specific commit only if you've hit recurring breakage — most taps work fine on HEAD.

## Lifecycle commands

```sh
brew install <name>                     # install bottle
brew install --cask <name>              # install cask
brew bundle install --file=manifests/Brewfile     # apply a Brewfile
brew bundle dump --file=manifests/Brewfile        # regenerate Brewfile from installed state
brew bundle cleanup --file=manifests/Brewfile     # show what's installed but not in Brewfile
brew bundle check --file=manifests/Brewfile       # verify Brewfile matches installed
brew upgrade                            # upgrade everything (bottles + casks)
brew upgrade <name>                     # upgrade one
brew pin <name>                         # prevent upgrade until unpin
brew unpin <name>                       # release the pin
brew outdated                           # list upgradable
brew uninstall <name>                   # uninstall (DESTRUCTIVE for casks — see below)
brew uninstall --zap --cask <name>      # also remove preferences/caches
brew autoremove                         # remove unused dependencies (run after uninstall)
brew cleanup                            # remove old versions, stale downloads
```

## Destruction semantics

**`brew uninstall --cask <name>` removes the `.app` from `/Applications`, not just the Homebrew metadata.** This catches people the first time. The intuition is "uninstall = remove the package manager's tracking, leave my apps alone" — that's not how casks work.

### What gets deleted by `brew uninstall --cask`

| Thing                                        | Removed by bare uninstall | Also removed by --zap |
| -------------------------------------------- | ------------------------- | --------------------- |
| `/Applications/<name>.app` (the app itself)  | YES                       | YES                   |
| `/opt/homebrew/Caskroom/<name>/` (metadata) | YES                       | YES                   |
| `/opt/homebrew/bin/<name>` (CLI symlink)    | YES                       | YES                   |
| `~/Library/Preferences/<bundle-id>.plist`   | NO                        | YES                   |
| `~/Library/Caches/<bundle-id>/`             | NO                        | YES                   |
| `~/Library/Application Support/<name>/`     | NO                        | YES                   |

`--zap` is for "I'm done with this app forever, clear all traces". Bare `uninstall` is "I no longer want this app installed but keep my settings if I reinstall".

### Detaching Homebrew from a cask without losing the app

Two safe patterns:

1. **Move the .app aside first**, uninstall, move it back:
   ```sh
   mv /Applications/<Name>.app /tmp/
   brew uninstall --cask <name>
   mv /tmp/<Name>.app /Applications/
   ```
   The brew metadata is gone; the app stays. Subsequent `brew upgrade` no longer touches it.

2. **Skip uninstall entirely** — delete the Caskroom directory and the symlink directly:
   ```sh
   rm -rf /opt/homebrew/Caskroom/<name>
   rm /opt/homebrew/bin/<name>     # if the cask shipped a CLI symlink
   ```
   Faster, fewer moves. brew has no record of the cask after this; the app is untouched.

Either pattern leaves you in a state where the next `brew bundle install` (without the `cask "<name>"` line) is a no-op. Add the tombstone comment in the Brewfile so the absence is intentional.

## Pinning

```sh
brew pin <name>                         # block this formula from `brew upgrade`
brew unpin <name>                       # release
brew list --pinned                      # what's pinned
```

Pin sparingly. The reason to pin should be documented in the Brewfile next to the entry:

```ruby
# Pinned at 1.4.x — 1.5 breaks the <foo> integration; revisit after <upstream-issue>.
brew "name@1.4"
```

Casks can't be pinned (the API has no `--cask` flag on `brew pin`). The cask equivalent is **manual install via DMG** — the migration described above. If you need to block a cask from auto-upgrade, the right tool is to remove the cask declaration entirely and capture the install in `scripts/install/<name>.sh`.

## Common pitfalls

| Symptom                                                                | Cause / Fix                                                                                                                |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `brew bundle install` hangs at an sudo prompt                          | A cask requires a `sudo` install (rare, e.g. system-extension installs). Re-run from a TTY where you can type the password. |
| `brew uninstall --cask` deleted the .app you wanted to keep            | See "Detaching Homebrew from a cask" above. Move the .app aside first, or skip the uninstall command.                       |
| `mas install <id>` fails with "Not signed in"                          | `mas signin` is deprecated since macOS 10.15. Sign in via System Settings → Apple ID, then re-run.                          |
| `mas install <id>` fails with "An item could not be purchased"          | Apple ID doesn't own the app. Buy/get it in the App Store first, THEN `mas install <id>` works on subsequent machines.       |
| `brew install` says "Error: Cannot install <name> because it is already installed" | An older `brew link --overwrite <name>` is needed, or the formula was relocated between taps.                                |
| Brewfile drift between machines                                        | Run `brew bundle dump --file=manifests/Brewfile --describe` to regenerate. Sort and groom by hand afterward.                |
| `brew upgrade` overwrote a manually-installed version                  | The cask was still declared. Either remove the cask declaration and add the manual install script, OR pin (bottles only).   |

## When NOT to use Homebrew

- Apps with critical update-cadence concerns (cmux today, possibly others). Use `scripts/install/<name>.sh` + Brewfile tombstone.
- Tools whose canonical installer self-updates (rustup, mise, nvm, etc.). Their built-in update mechanism is the right path.
- Apple-platform first-party apps that ship via App Store with App Store entitlements (iWork, Final Cut Pro, Logic Pro). Use `mas`.
- Apps with paid licenses that Homebrew has no way to track (1Password 7 Mac, Microsoft Office standalone). Brewfile entries that require manual activation are OK with a tombstone-style comment explaining the post-install step.

## Reload after editing the Brewfile

```sh
brew bundle install --file=manifests/Brewfile      # apply added entries (idempotent)
brew bundle check --file=manifests/Brewfile        # verify match
brew bundle cleanup --file=manifests/Brewfile      # list installed but absent from Brewfile
```

`bundle install` is idempotent — re-running with no changes is a no-op. Use it freely.
