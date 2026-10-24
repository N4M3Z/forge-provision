#!/bin/bash
# Generate per-harness SSH signing keys: passphrase-less ed25519, one per
# coding harness, so agent commits sign without touching the YubiKey. Keys
# register as Signing keys on the machine GitHub account, never the human's;
# the human attestation lane stays on the YubiKey (signed/* tags).
# Consumed by harness-run's JJ_CONFIG overlay ([signing] backend=ssh).
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

HARNESSES=(claude codex grok antigravity opencode)
KEY_DIR="${AGENT_SIGNING_KEY_DIR:-${HOME}/.ssh}"

generated=0
for harness in "${HARNESSES[@]}"; do
    key="${KEY_DIR}/${harness}"
    if [[ -f "${key}" ]]; then
        echo "skip:agent-signing-keys (${key} already exists)"
        continue
    fi
    if ! ssh-keygen -t ed25519 -N '' -C "${harness}@$(hostname -s)" \
        -f "${key}" -q; then
        echo "fail:agent-signing-keys (could not generate ${key})"
        exit 1
    fi
    chmod 600 "${key}"
    echo "ok:agent-signing-keys (generated ${key})"
    generated=$((generated + 1))
done

echo "ok:agent-signing-keys"
echo "      register each public key as a *Signing key* on the machine GitHub account:"
for harness in "${HARNESSES[@]}"; do
    [[ -f "${KEY_DIR}/${harness}.pub" ]] && echo "      $(cat "${KEY_DIR}/${harness}.pub")"
done
[[ "${generated}" -gt 0 ]] \
    && echo "      then run scripts/configure/agent-signing.sh for local verification"
