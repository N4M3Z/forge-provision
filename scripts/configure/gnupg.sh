#!/usr/bin/env bash
# Configure GnuPG for the YubiKey: pinentry-mac and PC/SC card access.
# Renders manifests/gnupg/ into ~/.gnupg, backs up any differing existing
# file with a dated suffix, reloads the agents. Idempotent.
#
# gpg-agent.conf needs a literal pinentry path — GnuPG conf files do not
# shell-expand — so ${BREW_PREFIX} is substituted here at render time.
# scdaemon.conf carries disable-ccid: GnuPG 2.3+ stopped falling back to
# PC/SC on its own, and macOS's CryptoTokenKit holds the USB device.
# pinentry-mac's "Save in Keychain" is disabled — a Keychain-stored PIN
# would defeat the per-signature PIN the card enforces.
#
# Decision: docs/decisions/ARCH-0006 (signing) + GPG-0001 (custody) +
# GPG-0005 (toolchain).
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

MANIFEST_DIR="${SCRIPT_DIR}/../../manifests/gnupg"
GNUPG_HOME="${HOME}/.gnupg"
CONF_FILES=(gpg-agent.conf scdaemon.conf)

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:gnupg (Homebrew not found — run scripts/install/brew.sh first)"
    exit 0
fi
BREW_PREFIX="$(brew --prefix)"

if [[ ! -x "${BREW_PREFIX}/bin/pinentry-mac" ]]; then
    echo "fail:gnupg (pinentry-mac not installed — run scripts/install/gpg-toolchain.sh first)"
    exit 0
fi

command mkdir -p "${GNUPG_HOME}"
command chmod 700 "${GNUPG_HOME}"

for config_name in "${CONF_FILES[@]}"; do
    source_file="${MANIFEST_DIR}/${config_name}"
    target_file="${GNUPG_HOME}/${config_name}"
    rendered_file="$(mktemp)"
    sed "s|\${BREW_PREFIX}|${BREW_PREFIX}|g" "${source_file}" > "${rendered_file}"

    if [[ -f "${target_file}" ]] && command cmp -s "${rendered_file}" "${target_file}"; then
        echo "skip:gnupg (${config_name} already current)"
        command rm -f "${rendered_file}"
        continue
    fi

    if [[ -f "${target_file}" ]]; then
        backup_file="${target_file}.$(date +%F).bak"
        command cp "${target_file}" "${backup_file}"
        echo "backup:${backup_file}"
    fi

    command install -m 0600 "${rendered_file}" "${target_file}"
    echo "install:${target_file}"
    command rm -f "${rendered_file}"
done

if [[ "$(defaults read org.gpgtools.pinentry-mac DisableKeychain 2>/dev/null)" == "1" ]]; then
    echo "skip:gnupg (pinentry Keychain already disabled)"
else
    defaults write org.gpgtools.pinentry-mac DisableKeychain -bool YES
    echo "config:pinentry-mac DisableKeychain=YES"
fi

if command -v gpgconf >/dev/null 2>&1; then
    gpgconf --kill gpg-agent scdaemon
fi

echo "ok:gnupg"
echo "      verify: gpg --card-status  (with the YubiKey inserted)"
