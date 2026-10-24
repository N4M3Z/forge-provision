#!/bin/bash
# Point git at the OpenPGP signing subkey of the YubiKey that is plugged in.
#
# The key is detected, not configured: gpg reports the card it currently sees,
# the fingerprint in that card's signature slot is looked up in the local secret
# keyring, and git gets that fingerprint pinned with a trailing "!" so gpg signs
# with this subkey and not with another subkey of the same primary. A machine
# that keeps several YubiKeys signs with the one inserted when this runs.
# GIT_SIGNING_KEY in .env replaces detection for a machine that must sign with
# one specific key; it still has to be a key gpg can use on this machine.
#
# Runs after git-signing-ssh.sh in the configure pass (alphabetical order), so
# when both signing paths are provisioned the OpenPGP default of ARCH-0006 is
# what remains in the global config. Idempotent.
#
# Decision: docs/decisions/ARCH-0006 Commit signing.md
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
source "${SCRIPT_DIR}/../lib/gpg.sh"

if ! command -v gpg >/dev/null 2>&1; then
    echo "fail:gpg-signing (gpg not found; run scripts/install/gpg-toolchain.sh)"
    exit 1
fi

usable_keys="$(gpg --list-secret-keys --with-colons 2>/dev/null | gpg_usable_signing_keys)"

if [[ -n "${GIT_SIGNING_KEY:-}" ]]; then
    selected="$(printf '%s\n' "${usable_keys}" | gpg_match_signing_key "${GIT_SIGNING_KEY}")"
    if [[ -z "${selected}" ]]; then
        echo "fail:gpg-signing (GIT_SIGNING_KEY ${GIT_SIGNING_KEY} is not a signing key gpg can use on this machine)"
        if [[ -n "${usable_keys}" ]]; then
            printf '%s\n' "${usable_keys}" | sed 's/^/      usable: /'
        fi
        exit 1
    fi
else
    card_fingerprint="$(gpg --card-status --with-colons 2>/dev/null | gpg_card_signature_fingerprint)"
    if [[ -z "${card_fingerprint}" ]]; then
        echo "fail:gpg-signing (no OpenPGP card with a signing key is present; insert the YubiKey, or set GIT_SIGNING_KEY in .env)"
        exit 1
    fi
    selected="$(printf '%s\n' "${usable_keys}" | gpg_match_signing_key "${card_fingerprint}")"
    if [[ -z "${selected}" ]]; then
        echo "fail:gpg-signing (the card's signing key ${card_fingerprint} has no entry in the local keyring; import its public key, then run gpg --card-status)"
        exit 1
    fi
fi

fingerprint="${selected%% *}"
remainder="${selected#* }"
location="${remainder%% *}"
user_id="${remainder#* }"
signing_key="0x${fingerprint}!"

set_global() {
    local key="$1" value="$2" current
    current="$(git config --global --get "${key}" 2>/dev/null || true)"
    if [[ "${current}" == "${value}" ]]; then
        echo "skip:${key} (already ${value})"
        return
    fi
    git config --global "${key}" "${value}"
    echo "config:${key}=${value}"
}

set_global gpg.format openpgp
set_global user.signingkey "${signing_key}"
set_global commit.gpgsign true
set_global tag.gpgsign true

echo "ok:gpg-signing (${user_id}, signing subkey ${fingerprint} on $(gpg_key_location_label "${location}"))"
echo "      test: git commit --allow-empty -m 'test: signed commit' && git log --show-signature -1"
