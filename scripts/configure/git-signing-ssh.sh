#!/bin/bash
# Configure git to sign commits + tags via the YubiKey-resident SSH key.
# Idempotent — git config writes are absolute; allowed_signers append is grep-guarded.
# Requires: scripts/install/ssh-yubikey-key.sh has run; GIT_EMAIL set in .env.
# Reference: https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

PUBKEY="${HOME}/.ssh/${SSH_KEY_NAME:-yubikey}.pub"
ALLOWED_SIGNERS="${HOME}/.config/git/allowed_signers"

if [[ ! -f "${PUBKEY}" ]]; then
    echo "fail:git-signing-ssh (no SSH public key at ${PUBKEY} — run scripts/install/ssh-yubikey-key.sh first)"
    exit 1
fi

if [[ -z "${GIT_EMAIL:-}" ]]; then
    echo "fail:git-signing-ssh (GIT_EMAIL must be set in .env)"
    exit 1
fi

echo "config:gpg.format=ssh"
git config --global gpg.format ssh

# Apple's /usr/bin/ssh-keygen lacks the libsk-libfido2 FIDO middleware. brew's
# /opt/homebrew/bin/ssh-keygen has it. Without this config, git signing fails
# with "No FIDO SecurityKeyProvider specified" on every commit.
SSH_KEYGEN=/opt/homebrew/bin/ssh-keygen
[[ -x "${SSH_KEYGEN}" ]] || SSH_KEYGEN=/usr/local/bin/ssh-keygen  # Intel
echo "config:gpg.ssh.program=${SSH_KEYGEN}"
git config --global gpg.ssh.program "${SSH_KEYGEN}"

echo "config:user.signingkey=${PUBKEY}"
git config --global user.signingkey "${PUBKEY}"

echo "config:commit.gpgsign=true"
git config --global commit.gpgsign true

echo "config:tag.gpgsign=true"
git config --global tag.gpgsign true

# allowed_signers enables `git log --show-signature` and `git verify-commit` locally
mkdir -p "$(dirname "${ALLOWED_SIGNERS}")"
PUB_KEY_FIELDS="$(awk '{print $1, $2}' "${PUBKEY}")"
ENTRY="${GIT_EMAIL} ${PUB_KEY_FIELDS}"

if [[ -f "${ALLOWED_SIGNERS}" ]] && grep -qxF "${ENTRY}" "${ALLOWED_SIGNERS}"; then
    echo "skip:allowed_signers (${GIT_EMAIL} already entered)"
else
    echo "${ENTRY}" >> "${ALLOWED_SIGNERS}"
    echo "append:allowed_signers (${GIT_EMAIL})"
fi

echo "config:gpg.ssh.allowedSignersFile=${ALLOWED_SIGNERS}"
git config --global gpg.ssh.allowedSignersFile "${ALLOWED_SIGNERS}"

echo "ok:git-signing-ssh"
echo "      test: git commit --allow-empty -m 'test signing' && git log --show-signature -1"
