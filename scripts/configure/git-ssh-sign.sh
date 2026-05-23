#!/bin/bash
# Install the macOS wrapper that bypasses Apple's launchd ssh-agent for git
# commit signing with sk-ssh-ed25519 (FIDO2) keys, then point git's
# gpg.ssh.program at it. The wrapper itself ships with forge-core in
# skills/VersionControl/scripts/git-ssh-sign-macos — see that skill's
# CommitSigning.md for the diagnosis of Apple's "agent refused operation"
# failure mode. Run after scripts/configure/git-signing-ssh.sh (which sets
# gpg.format=ssh and user.signingkey). Idempotent.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

WRAPPER_SOURCE="${DEV_DIR}/forge-core/skills/VersionControl/scripts/git-ssh-sign-macos"
WRAPPER_TARGET="${HOME}/.local/bin/git-ssh-sign-macos"

if [[ ! -f "${WRAPPER_SOURCE}" ]]; then
    echo "fail:git-ssh-sign (wrapper source not found at ${WRAPPER_SOURCE} — clone forge-core into \${DEV_DIR} first)"
    exit 1
fi

command mkdir -p "$(command dirname "${WRAPPER_TARGET}")"

if [[ -f "${WRAPPER_TARGET}" ]] && command cmp -s "${WRAPPER_SOURCE}" "${WRAPPER_TARGET}"; then
    echo "skip:git-ssh-sign wrapper (${WRAPPER_TARGET} already current)"
else
    command install -m 0755 "${WRAPPER_SOURCE}" "${WRAPPER_TARGET}"
    echo "install:${WRAPPER_TARGET}"
fi

CURRENT_PROGRAM="$(command git config --global --get gpg.ssh.program 2>/dev/null || true)"
if [[ "${CURRENT_PROGRAM}" == "${WRAPPER_TARGET}" ]]; then
    echo "skip:gpg.ssh.program (already ${WRAPPER_TARGET})"
else
    command git config --global gpg.ssh.program "${WRAPPER_TARGET}"
    echo "config:gpg.ssh.program=${WRAPPER_TARGET}"
fi

echo "ok:git-ssh-sign"
echo "      verify: git commit --allow-empty -m 'test signing'  (YubiKey should blink for touch)"
