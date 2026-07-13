# forge-provision

> Idempotent shell that brings a fresh macOS install to a working baseline.

I want you to provision this Mac. First determine what is already here, then ask me which scopes to apply, then execute the scriptable steps autonomously and surface the manual steps to me — macOS keeps those settings in formats no script can touch, so I complete them by hand.

## OBJECTIVE

Bring a fresh macOS install to the owner's working baseline (Homebrew apps, configure scripts, macOS defaults, shell environment) — scoped to what the owner approves for this machine — then hand off the settings macOS does not expose to scripting.

## DONE WHEN

`brew bundle check --file=manifests/Brewfile` reports the approved dependencies satisfied, `./provision.sh --topic verify` passes, `git config --global user.email` shows a real identity (not a placeholder), and every box under **Manual steps** has been completed by the operator.

## TODO

- [ ] Install prerequisites (Xcode CLT, Homebrew, git)
- [ ] Copy `.env.example` to `.env` and set the identity values with the operator
- [ ] Inventory the machine and ask the operator which scopes to apply
- [ ] Run the approved topic scripts via `provision.sh`
- [ ] Hand the **Manual steps** to the operator and confirm they are done

## Steps

### Prerequisites

```sh
xcode-select -p || xcode-select --install
brew --version || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git --version
```

### Clone and identify

```sh
git clone https://github.com/N4M3Z/forge-provision.git
cd forge-provision
cp .env.example .env    # then edit: GIT_NAME, GIT_EMAIL, GITHUB_USER, paths
```

`.env` is mandatory: `scripts/lib/env.sh` warns on the placeholder fallback and
`scripts/configure/git-identity.sh` refuses to write placeholder identity.
On a work machine, use the work identity here, plus:

- `SCOPE="work"` — selects `manifests/Brewfile.work`, the deterministic
  corporate subset (personal apps, media, session capture, and key-custody
  ceremony tools excluded; OrbStack included, licensed corporately, activate
  manually after install).
- `DOTFILES_REPO` — the chezmoi source to deploy; leave empty to skip
  dotfiles entirely.

### Inventory, then ask

Before mutating anything, determine the machine's state and preview the plan:

```sh
./provision.sh --dry-run
brew bundle check --file=manifests/Brewfile || true
```

Then ask the operator which scopes to apply — the Brewfile and scripts mirror the
owner's personal machine, and several groups are opt-in on a managed or work device:

- **Core dev toolchain** — shell (starship, atuin, zoxide, fzf), git/jj tooling,
  editors, terminal, review TUIs. Safe everywhere; the usual baseline.
- **Identity and signing** — GPG/YubiKey toolchain, keyvault scaffold, ssh keys,
  git identity. Needs the operator's hardware key and the identity in `.env`.
- **AI harnesses and cloud CLIs** — Claude Code, Codex, Antigravity, Grok,
  wrangler, Browserbase. Each has its own account/auth; install only what this
  machine's policy allows.
- **Local AI stack** — Ollama, oMLX, LM Studio, brain stack (Postgres+pgvector,
  gbrain, sabiql), SpecStory session capture. Heavier installs; check data policy.
- **Personal apps and media** — SuperWhisper, MacWhisper, Discord + Little Snitch,
  iStat Menus, Steam and MAS entries (personal Apple ID), Parallels. Licensing and
  network policy apply on a work device.
- **System posture** — macOS defaults via chezmoi, dcg destructive-command guard,
  sandbox/container runtimes (OrbStack, Apple container), firefox hardened profile.

Skip anything the operator declines: `brew bundle` installs the whole Brewfile, so
for a partial scope install the approved entries with `brew install`/`brew install
--cask` directly, or comment out declined sections in a local Brewfile copy.

### Execute

```sh
./provision.sh --topic install
./provision.sh --topic configure
./provision.sh --topic verify
# migrate/ and clone/ topics only when bringing state over from the old Mac:
./provision.sh --topic migrate
./provision.sh --topic clone
```

Interactive auth the scripts cannot do headlessly: `gh auth login`,
`codex login`, `agy` (Google sign-in), `wrangler login`, MAS sign-in.

### Manual steps

macOS keeps some settings in formats with no scriptable interface. An agent cannot do these — surface them to the operator, who completes each by hand:

- [ ] **Finder sidebar order** — drag the favorites into the order you want in any Finder window. The order lives in a binary, machine-specific bookmark plist (`com.apple.LSSharedFileList.FavoriteItems.sfl4`) with no `defaults` interface, and the only CLI for it (`mysides`) is deprecated.
- [ ] **Control Center / menu-bar item arrangement** — in System Settings > Control Center, set which icons show in the menu bar (Bluetooth, Sound, Battery %, Focus, etc.) and drag them into order. macOS 26 stores this in an opaque `MenuBarCustomizationState` blob with no per-item `defaults` interface. (The clock and the Time Machine + VPN extras are scripted in `dot_macos`.)
- [ ] **TCC grants** — Little Snitch system extension, Screen Recording / Accessibility for Codex Computer Use, EventKit for calendar tools: approve in System Settings when prompted.

No manual step is needed for Thaw (it is in `manifests/Brewfile`) or screenshot settings (left at the macOS default — provisioning sets no `com.apple.screencapture` keys).

### Verify

```sh
brew bundle check --file=manifests/Brewfile
./provision.sh --topic verify
git config --global user.email
test -f ~/.macos && echo "macos defaults applied"
```

EXECUTE NOW: Complete the TODO list — inventory first, ask the operator for scope, then bring this Mac to the approved baseline and confirm the operator has finished the Manual steps.
