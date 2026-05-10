#!/bin/bash
# Clone reference repos into ${DEV_DIR} so we can read and copy from them.
# Idempotent: skips repos that already exist.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

mkdir -p "$DEV_DIR"

clone_if_missing() {
    local url="$1"
    local dest="$2"
    if [[ -d "${DEV_DIR}/${dest}" ]]; then
        echo "skip:${dest} (exists)"
    else
        if git clone --quiet "$url" "${DEV_DIR}/${dest}" 2>/dev/null; then
            echo "clone:${dest} ok"
        else
            echo "clone:${dest} failed"
        fi
    fi
}

# User's own public repos
clone_if_missing "https://github.com/${GITHUB_USER}/forge-cli.git"  forge-cli
clone_if_missing "https://github.com/${GITHUB_USER}/check-mac.git"  check-mac
clone_if_missing "https://github.com/${GITHUB_USER}/mac-setup.git"  mac-setup
clone_if_missing "https://github.com/${GITHUB_USER}/dotfiles.git"   dotfiles

# Private — needs SSH key on this machine; fails gracefully if not yet set up
clone_if_missing "git@github.com:${GITHUB_USER}/dotfiles-private.git" dotfiles-private

# External canonical reference
clone_if_missing "https://github.com/drduh/macOS-Security-and-Privacy-Guide.git" macOS-Security-and-Privacy-Guide
