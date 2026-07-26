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

# A GPG Suite install shadows Homebrew gnupg with MacGPG 2.2.x. GPG-0005 keeps
# it off the machine, so report the components found and remove them on request.
# GPGTools ships no uninstaller script, so removal is receipt-based: forget the
# pkgutil receipts, then delete what they installed.
GPG_SUITE_PATHS=(
    "/Applications/GPG Keychain.app"
    "/usr/local/MacGPG2"
    "/Library/Services/GPGServices.service"
    "/Library/PreferencePanes/GPGPreferences.prefPane"
)

suite_found=()
for path in "${GPG_SUITE_PATHS[@]}"; do
    [[ -e "${path}" ]] && suite_found+=("${path}")
done
suite_receipts="$(pkgutil --pkgs 2>/dev/null | grep '^org\.gpgtools\.' || true)"

if [[ ${#suite_found[@]} -gt 0 || -n "${suite_receipts}" ]]; then
    installed_gpg="$(command -v gpg 2>/dev/null)"
    echo "warn:gpg-toolchain (GPG Suite / MacGPG present — ships gpg 2.2.x and shares"
    echo "      ~/.gnupg with Homebrew gnupg; GPG-0005 keeps one gpg on the machine)"
    echo "      git and scripts currently resolve gpg to: ${installed_gpg:-none}"
    for path in "${suite_found[@]}"; do
        echo "      found: ${path}"
    done

    # Removal deletes system paths and needs sudo, so it never runs as a side
    # effect of a topic pass: it is opt-in and refuses without a terminal.
    if [[ "${FORGE_REMOVE_GPG_SUITE:-}" != "1" ]]; then
        echo "manual:gpg-toolchain (remove with: FORGE_REMOVE_GPG_SUITE=1 ${BASH_SOURCE[0]})"
    elif [[ ! -t 0 ]]; then
        echo "manual:gpg-toolchain (removal needs an interactive terminal for sudo; rerun it yourself)"
    else
        echo "remove:gpg-suite (receipts, then installed paths)"
        while IFS= read -r receipt; do
            [[ -z "${receipt}" ]] && continue
            echo "      forget: ${receipt}"
            sudo pkgutil --forget "${receipt}" >/dev/null || echo "      warn: could not forget ${receipt}"
        done <<< "${suite_receipts}"
        for path in "${suite_found[@]}"; do
            echo "      delete: ${path}"
            sudo rm -rf "${path}" || echo "      warn: could not delete ${path}"
        done
        echo "      ~/.gnupg is left untouched; it holds your keyring, not GPG Suite"
        echo "      restart the agent afterwards: gpgconf --kill gpg-agent"
    fi
fi

echo "ok:gpg-toolchain (${FORMULAE[*]})"
