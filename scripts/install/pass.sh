#!/usr/bin/env bash
# Install pass (password-store) and the pass-otp extension from Homebrew.
# Idempotent: skips formulae already installed.
#
# The store is GPG-backed against the YubiKey-resident key (GPG-0001), so
# every entry decrypt is gated by the card. OTP secrets are ordinary store
# entries handled by pass-otp — not superseded, still the canonical extension.
#
# Decision: docs/decisions/GPG-0001 (custody) + GPG-0005 (toolchain lane).
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FORMULAE=(pass pass-otp)

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:pass (Homebrew not found — run scripts/install/brew.sh first)"
    exit 0
fi

for formula in "${FORMULAE[@]}"; do
    if brew list --formula "${formula}" >/dev/null 2>&1; then
        echo "skip:pass (${formula} already installed)"
        continue
    fi
    echo "install:pass (${formula})"
    brew install "${formula}"
done

echo "ok:pass (${FORMULAE[*]})"
