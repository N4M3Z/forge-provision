#!/bin/bash
# Configure git to sign commits + tags with the OpenPGP signing subkey on the
# YubiKey — the default signing lane per ARCH-0006, with SSH/FIDO2 the
# documented alternative (scripts/configure/git-signing-ssh.sh).
# Key custody is GPG-0001: subkeys on the card, master offline.
# Idempotent: git config writes are absolute.
#
# GPG_SIGNING_KEY in .env pins the key. Left empty, the sign-capable secret
# key in the keyring is detected instead, which is the stub the card presents.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v gpg >/dev/null 2>&1; then
    echo "fail:git-signing-openpgp (gpg not on PATH; run scripts/install/gpg-toolchain.sh)"
    exit 1
fi

# A GPG Suite install puts MacGPG 2.2.x alongside Homebrew's gpg. Which one
# git ends up calling then depends on PATH order, so name the binary
# explicitly rather than inheriting whatever resolves first (GPG-0005).
GPG_BINARY="$(command -v gpg)"

KEY="${GPG_SIGNING_KEY:-}"

if [[ -z "${KEY}" ]]; then
    # Field 5 of an ssb line is the keyid; capability 's' marks it sign-capable.
    KEY="$(gpg --list-secret-keys --with-colons 2>/dev/null \
        | awk -F: '$1 == "ssb" && $12 ~ /s/ { print $5; exit }')"
fi

if [[ -z "${KEY}" ]]; then
    echo "fail:git-signing-openpgp (no sign-capable secret key found)"
    echo "      insert the YubiKey and run 'gpg --card-status' to create the keyring stubs,"
    echo "      or set GPG_SIGNING_KEY in .env to the signing subkey id"
    exit 1
fi

# The trailing ! pins signing to this exact subkey instead of letting gpg pick
# the newest sign-capable one (ARCH-0006).
echo "config:user.signingkey=${KEY}!"
git config --global user.signingkey "${KEY}!"

echo "config:gpg.format=openpgp"
git config --global gpg.format openpgp

echo "config:gpg.program=${GPG_BINARY}"
git config --global gpg.program "${GPG_BINARY}"

echo "config:commit.gpgsign=true"
git config --global commit.gpgsign true

echo "config:tag.gpgsign=true"
git config --global tag.gpgsign true

echo "ok:git-signing-openpgp (${KEY})"
echo "      verify: scripts/verify/signing.sh"
