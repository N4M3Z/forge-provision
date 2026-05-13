#!/bin/bash
# Apply baseline macOS defaults for Finder, Dock, Trackpad/Keyboard.
# Idempotent — `defaults write` of the same value is a no-op.
#
# Caveats inherited from check-mac/docs/decisions/ARCH-0001 and ARCH-0003:
# - Some keys are no-ops on macOS 15+/26+ where Apple has moved policy to Declarative
#   Device Management. We accept that and print `defaults read` after each write so
#   the user can see what actually took.
# - The user reviews this script and prunes / extends to match their preference.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

set_and_show() {
    local domain="$1" key="$2"
    shift 2
    defaults write "$domain" "$key" "$@"
    printf "  %s.%s = %s\n" "$domain" "$key" "$(defaults read "$domain" "$key" 2>/dev/null)"
}

echo "configure:appearance"
set_and_show NSGlobalDomain AppleInterfaceStyle -string "Dark"

echo ""
echo "configure:finder"
set_and_show com.apple.finder AppleShowAllFiles -bool true
set_and_show NSGlobalDomain AppleShowAllExtensions -bool true
set_and_show com.apple.finder ShowPathbar -bool true
set_and_show com.apple.finder ShowStatusBar -bool true
set_and_show com.apple.finder FXPreferredViewStyle -string "Nlsv"
set_and_show com.apple.finder FXEnableExtensionChangeWarning -bool false
killall Finder 2>/dev/null || true

echo ""
echo "configure:dock"
set_and_show com.apple.dock autohide -bool true
set_and_show com.apple.dock autohide-delay -float 0
set_and_show com.apple.dock autohide-time-modifier -float 0
set_and_show com.apple.dock show-recents -bool false
set_and_show com.apple.dock minimize-to-application -bool true
set_and_show com.apple.dock orientation -string "right"
# Hot corners: 0=none, 2=Mission Control, 3=Application windows, 4=Desktop,
# 5=Start screen saver, 6=Disable screen saver, 7=Dashboard, 10=Sleep, 11=Launchpad,
# 12=Notification Center, 13=Lock Screen, 14=Quick Note.
set_and_show com.apple.dock wvous-br-corner -int 14
killall Dock 2>/dev/null || true

echo ""
echo "configure:trackpad-keyboard"
set_and_show com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
set_and_show NSGlobalDomain com.apple.mouse.tapBehavior -int 1
set_and_show NSGlobalDomain KeyRepeat -int 2
set_and_show NSGlobalDomain InitialKeyRepeat -int 15
killall SystemUIServer 2>/dev/null || true

echo ""
echo "ok:macos-defaults"
echo "      restart Finder/Dock/menu-bar via killall above; some keys may no-op under DDM"
