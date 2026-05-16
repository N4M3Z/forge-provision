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

# Close System Settings (Ventura+) and the older System Preferences app to
# prevent them from caching values in memory and writing stale state back
# over our changes when their window closes. Borrowed from the mathiasbynens
# .macos pattern. Both calls are best-effort; silent if the app is not open.
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true

echo "configure:appearance"
set_and_show NSGlobalDomain AppleInterfaceStyle -string "Dark"

echo ""
echo "configure:finder"
set_and_show com.apple.finder AppleShowAllFiles -bool true
set_and_show NSGlobalDomain AppleShowAllExtensions -bool true
set_and_show com.apple.finder ShowPathbar -bool true
set_and_show com.apple.finder ShowStatusBar -bool true
set_and_show com.apple.finder FXPreferredViewStyle -string "clmv"
set_and_show com.apple.finder FXEnableExtensionChangeWarning -bool false
# Show external + removable media on the Desktop; hide internal drives.
set_and_show com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
set_and_show com.apple.finder ShowHardDrivesOnDesktop -bool false
set_and_show com.apple.finder ShowRemovableMediaOnDesktop -bool true
# Auto-empty Trash after 30 days.
set_and_show com.apple.finder FXRemoveOldTrashItems -bool true
# Group and arrange by Kind in the app-centric Finder view.
set_and_show com.apple.finder FXPreferredGroupBy -string "Kind"
set_and_show com.apple.finder FK_ArrangeBy -string "Kind"
# Show sidebar in app-centric Finder windows.
set_and_show com.apple.finder FK_AppCentricShowSidebar -bool true

# Unhide ~/Library. Apple hides it since 10.7 Lion via TWO mechanisms: the
# BSD `hidden` chflag AND the kIsInvisible bit in the com.apple.FinderInfo
# xattr. Clear both. xattr removal is silenced if the xattr is absent.
# ~/Documents and ~/Desktop are not BSD-hidden on this Mac; their Finder
# routing is governed by iCloud Drive's "Desktop & Documents Folders"
# feature, which is a separate mechanism (file-provider detach xattr).
chflags nohidden "$HOME/Library"
xattr -d com.apple.FinderInfo "$HOME/Library" 2>/dev/null || true
printf "  ~/Library flags = %s\n" "$(stat -f '%Sf' "$HOME/Library")"

killall Finder 2>/dev/null || true

echo ""
echo "configure:disk-stores"
# Suppress .DS_Store on network and USB volumes. Keeps shared drives clean
# and avoids polluting USB sticks that get shared with non-Mac users.
set_and_show com.apple.desktopservices DSDontWriteNetworkStores -bool true
set_and_show com.apple.desktopservices DSDontWriteUSBStores -bool true

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
# Use 'scale' (not 'genie') minimize animation.
set_and_show com.apple.dock mineffect -string "scale"
# Small icons (default 64). 36 keeps the right-side dock unobtrusive.
set_and_show com.apple.dock tilesize -int 36
# Don't auto-rearrange Spaces by most-recent-use. Spaces stay where placed.
set_and_show com.apple.dock mru-spaces -bool false
# No launch-bounce animation when an app starts.
set_and_show com.apple.dock launchanim -bool false
# Faster Mission Control / App Exposé transitions.
set_and_show com.apple.dock expose-animation-duration -float 0.1
# Mission Control: don't group windows by app (one tile per window).
set_and_show com.apple.dock expose-group-apps -bool false
killall Dock 2>/dev/null || true

echo ""
echo "configure:typing-code"
# Disable text "helpers" that fight with code editors and terminals: smart
# quotes/dashes/periods, auto-capitalization, auto-correct, auto-completion.
# Press-and-hold off means a held key repeats (essential for vim/code) instead
# of opening the accented-character picker.
set_and_show NSGlobalDomain ApplePressAndHoldEnabled -bool false
set_and_show NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
set_and_show NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
set_and_show NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
set_and_show NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
set_and_show NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
set_and_show NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false

echo ""
echo "configure:trackpad-keyboard"
set_and_show com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
set_and_show NSGlobalDomain com.apple.mouse.tapBehavior -int 1
set_and_show NSGlobalDomain KeyRepeat -int 2
set_and_show NSGlobalDomain InitialKeyRepeat -int 15
# Disable corner-as-right-click (two-finger tap handles secondary-click).
set_and_show com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0
# Keep trackpad active even when a USB mouse is plugged in.
set_and_show com.apple.AppleMultitouchTrackpad USBMouseStopsTrackpad -int 0
# Two-finger swipe from the right edge opens Notification Center.
set_and_show com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
killall SystemUIServer 2>/dev/null || true

echo ""
echo "configure:window-manager"
# Stage Manager off.
set_and_show com.apple.WindowManager GloballyEnabled -bool false
# Clicking the wallpaper does NOT hide windows.
set_and_show com.apple.WindowManager HideDesktop -bool true
# Sequoia window tiling: no rounded-corner margin gap around tiled windows.
set_and_show com.apple.WindowManager EnableTiledWindowMargins -bool false
killall WindowManager 2>/dev/null || true

echo ""
echo "configure:menubar-clock"
# Compact menu-bar clock: day-of-week + AM/PM, no date. Keeps the menu bar
# tight next to the notch on Mac17,6 ("Wed 3:14 PM" rather than the longer
# default with the date).
set_and_show com.apple.menuextra.clock ShowDayOfWeek -bool true
set_and_show com.apple.menuextra.clock ShowAMPM -bool true
set_and_show com.apple.menuextra.clock ShowDate -int 0
killall SystemUIServer 2>/dev/null || true

echo ""
echo "ok:macos-defaults"
echo "      restart Finder/Dock/menu-bar via killall above; some keys may no-op under DDM"
