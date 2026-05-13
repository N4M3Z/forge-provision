#!/bin/bash
# Generate a YubiKey-resident ed25519-sk SSH key (FIDO2).
# The private blob stays on the YubiKey; ~/.ssh/${SSH_KEY_NAME} is just a handle.
# Same key serves SSH auth AND git SSH-signing (see scripts/configure/git-signing-ssh.sh).
#
# Resident + verify-required = the key can be re-derived on another machine via
# `ssh-keygen -K` from the YubiKey, and every use requires PIN + touch.
#
# Reference: man ssh-keygen ("-t ed25519-sk"); macOS 13+ ships libfido2-enabled OpenSSH.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

KEY="${HOME}/.ssh/${SSH_KEY_NAME:-yubikey}"
APPLICATION="${SSH_YUBIKEY_APPLICATION:-ssh:${GITHUB_USER:-user}}"
COMMENT="${GIT_EMAIL:-${USER}@$(hostname -s)}"

# Idempotent: skip if the handle file already exists
if [[ -f "${KEY}" ]]; then
    echo "skip:ssh-yubikey-key (${KEY} already exists)"
    echo "      public key:"
    cat "${KEY}.pub"
    exit 0
fi

# Use brew's openssh — it has FIDO2 security-key middleware built in.
# macOS's bundled /usr/bin/ssh-keygen knows the ed25519-sk algorithm but lacks the
# libsk-libfido2 wrapper, and pointing it at raw libfido2.dylib fails with
# "provider is not an OpenSSH FIDO library".
SSH_KEYGEN=/opt/homebrew/bin/ssh-keygen
[[ -x "${SSH_KEYGEN}" ]] || SSH_KEYGEN=/usr/local/bin/ssh-keygen  # Intel
if [[ ! -x "${SSH_KEYGEN}" ]]; then
    echo "fail:ssh-yubikey-key (brew openssh not found — brew install openssh)"
    exit 1
fi

# ~/.ssh permissions
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

echo "generate:${SSH_KEY_NAME:-yubikey} (resident, verify-required, application=${APPLICATION})"
echo "      insert YubiKey and follow the prompts (you will tap it once)"

"${SSH_KEYGEN}" \
    -t ed25519-sk \
    -O resident \
    -O verify-required \
    -O application="${APPLICATION}" \
    -C "${COMMENT}" \
    -f "${KEY}" \
    -N "" || {
        echo "fail:ssh-keygen"
        exit 1
    }

chmod 600 "${KEY}" "${KEY}.pub"

echo "ok:ssh-yubikey-key"
echo "      public key:"
cat "${KEY}.pub"
echo ""
echo "      next:"
echo "        gh auth login                                                       # interactive"
echo "        gh ssh-key add ${KEY}.pub --title \"\$(hostname -s)\"                   # auth key"
echo "        gh ssh-key add ${KEY}.pub --type signing --title \"\$(hostname -s) signing\"   # signing key"
echo "        ./scripts/configure/git-identity.sh"
echo "        ./scripts/configure/git-signing-ssh.sh"
