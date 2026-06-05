#!/usr/bin/env bash
# Install the GPG toolchain from Homebrew (not GPG Suite / GPGTools).
# Idempotent: skips formulae already installed.
#
# Homebrew gnupg (2.5.x) instead of GPG Suite's MacGPG (2.2.x): one current
# gpg on PATH, no paid GPGMail, no redundant GPG Keychain, no dual-gpg fight
# over ~/.gnupg. Backup tooling (paperkey, qrencode) is a separate concern:
# scripts/install/paperkey.sh.
#
# Decision: docs/decisions/GPG-0005 (toolchain) + GPG-0001 (custody) +
# ARCH-0006 (signing).
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FORMULAE=(gnupg pinentry-mac ykman)

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:gpg-toolchain (Homebrew not found — run scripts/install/brew.sh first)"
    exit 0
fi

for formula in "${FORMULAE[@]}"; do
    if brew list --formula "${formula}" >/dev/null 2>&1; then
        echo "skip:gpg-toolchain (${formula} already installed)"
        continue
    fi
    echo "install:gpg-toolchain (${formula})"
    brew install "${formula}"
done

# A GPG Suite install would shadow Homebrew gnupg with MacGPG 2.2.x.
if [[ -e "/Applications/GPG Keychain.app" || -d "/usr/local/MacGPG2" ]]; then
    echo "warn:gpg-toolchain (GPG Suite / MacGPG present — it ships gpg 2.2.x and"
    echo "      collides with Homebrew gnupg over ~/.gnupg; uninstall it, see GPG-0005)"
fi

echo "ok:gpg-toolchain (${FORMULAE[*]})"
