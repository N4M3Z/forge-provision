# forge-provision

> Idempotent shell that brings a fresh macOS install to a working baseline.

I want you to provision this Mac. Execute the scriptable steps below autonomously, then surface the manual steps to me — macOS keeps those settings in formats no script can touch, so I complete them by hand.

## OBJECTIVE

Bring a fresh macOS install to the working baseline (Homebrew apps, macOS defaults, shell environment), then hand off the settings macOS does not expose to scripting.

## DONE WHEN

`brew bundle check --file=manifests/Brewfile` reports the dependencies satisfied, `~/.macos` exists (defaults applied), and every box under **Manual steps** has been completed by the operator.

## TODO

- [ ] Install prerequisites (Homebrew, git)
- [ ] Install apps from the Brewfile
- [ ] Apply macOS defaults and shell config
- [ ] Hand the **Manual steps** to the operator and confirm they are done

## Steps

### Prerequisites

```sh
brew --version
git --version
```

### Install

```sh
git clone https://github.com/N4M3Z/forge-provision.git
cd forge-provision
brew bundle install --file=manifests/Brewfile
./provision.sh                 # runs topic scripts (filled in as they land)
```

### Manual steps

macOS keeps some settings in formats with no scriptable interface. An agent cannot do these — surface them to the operator, who completes each by hand:

- [ ] **Finder sidebar order** — drag the favorites into the order you want in any Finder window. The order lives in a binary, machine-specific bookmark plist (`com.apple.LSSharedFileList.FavoriteItems.sfl4`) with no `defaults` interface, and the only CLI for it (`mysides`) is deprecated.
- [ ] **Control Center / menu-bar item arrangement** — in System Settings > Control Center, set which icons show in the menu bar (Bluetooth, Sound, Battery %, Focus, etc.) and drag them into order. macOS 26 stores this in an opaque `MenuBarCustomizationState` blob with no per-item `defaults` interface. (The clock and the Time Machine + VPN extras are scripted in `dot_macos`.)

No manual step is needed for Thaw (it is in `manifests/Brewfile`) or screenshot settings (left at the macOS default — provisioning sets no `com.apple.screencapture` keys).

### Verify

```sh
brew bundle check --file=manifests/Brewfile
test -f ~/.macos && echo "macos defaults applied"
```

EXECUTE NOW: Complete the TODO list to bring this Mac to baseline, then confirm the operator has finished the Manual steps.
