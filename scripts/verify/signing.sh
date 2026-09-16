#!/bin/bash
# Verify the global git signing configuration can produce a signature on this
# machine: gpg.format is openpgp, commit signing is on, and user.signingkey
# names a signing key whose private material gpg can reach, on disk or on a
# known card. A key id carried over from another machine passes `git config`
# and fails at the first commit; this surfaces it at provision time instead.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
source "${SCRIPT_DIR}/../lib/gpg.sh"

format="$(git config --global --get gpg.format 2>/dev/null || true)"
if [[ "${format}" == "ssh" ]]; then
    echo "skip:signing (gpg.format=ssh; the OpenPGP check does not apply)"
    exit 0
fi
if [[ "${format}" != "openpgp" ]]; then
    echo "fail:signing (gpg.format is '${format:-unset}', expected openpgp; run scripts/configure/gpg-signing.sh)"
    exit 1
fi

signing_key="$(git config --global --get user.signingkey 2>/dev/null || true)"
if [[ -z "${signing_key}" ]]; then
    echo "fail:signing (user.signingkey unset; run scripts/configure/gpg-signing.sh with the YubiKey inserted)"
    exit 1
fi

if [[ "$(git config --global --get commit.gpgsign 2>/dev/null || true)" != "true" ]]; then
    echo "fail:signing (commit.gpgsign is not true; run scripts/configure/gpg-signing.sh)"
    exit 1
fi

if ! command -v gpg >/dev/null 2>&1; then
    echo "fail:signing (gpg not found; run scripts/install/gpg-toolchain.sh)"
    exit 1
fi

matched="$(gpg --list-secret-keys --with-colons 2>/dev/null | gpg_usable_signing_keys | gpg_match_signing_key "${signing_key}")"
if [[ -z "${matched}" ]]; then
    echo "fail:signing (user.signingkey ${signing_key} is not a signing key gpg can use on this machine; run scripts/configure/gpg-signing.sh with the YubiKey inserted)"
    exit 1
fi

fingerprint="${matched%% *}"
remainder="${matched#* }"
location="${remainder%% *}"
user_id="${remainder#* }"

card_fingerprint="$(gpg --card-status --with-colons 2>/dev/null | gpg_card_signature_fingerprint)"
if [[ "${location}" == "+" || "${card_fingerprint}" == "${fingerprint}" ]]; then
    presence="ready"
else
    presence="card not inserted"
fi

echo "ok:signing (${user_id}, signing subkey ${fingerprint} on $(gpg_key_location_label "${location}"), ${presence})"
