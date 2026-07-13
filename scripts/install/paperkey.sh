#!/usr/bin/env bash
# Install the physical key-backup tooling: paperkey + qrencode.
# Idempotent: skips formulae already installed.
#
# paperkey strips an OpenPGP secret key to the bytes that cannot be
# reconstructed from the public key; qrencode renders them as QR codes for
# OCR-free recovery, printed alongside paperkey's own text output. Kept
# separate from the GPG toolchain because backup tooling has its own decision
# and lifecycle.
#
# Decision: docs/decisions/GPG-0006 (physical key backup) + GPG-0004
# (generation ceremony that uses these at backup time).
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FORMULAE=(paperkey qrencode)

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:paperkey (Homebrew not found — run scripts/install/brew.sh first)"
    exit 0
fi

for formula in "${FORMULAE[@]}"; do
    if brew list --formula "${formula}" >/dev/null 2>&1; then
        echo "skip:paperkey (${formula} already installed)"
        continue
    fi
    echo "install:paperkey (${formula})"
    brew install "${formula}"
done

echo "ok:paperkey (${FORMULAE[*]})"
