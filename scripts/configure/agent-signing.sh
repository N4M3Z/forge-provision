#!/bin/bash
# Register the per-harness signing keys in allowed_signers so agent-signed
# commits verify locally (`git log --show-signature`, `jj log`). Committer
# emails follow <harness>@noreply.<hostname>.local (override with
# AGENT_SIGNING_DOMAIN in .env), matching harness-run's identity overlay;
# the hostname names which machine's agent made the commit.
# Idempotent: appends are grep-guarded, existing entries skipped.
# Requires: scripts/install/agent-signing-keys.sh.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

HARNESSES=(claude codex grok antigravity opencode)
KEY_DIR="${AGENT_SIGNING_KEY_DIR:-${HOME}/.ssh}"
ALLOWED_SIGNERS="${HOME}/.config/git/allowed_signers"

machine="$(hostname -s | tr '[:upper:]' '[:lower:]')"
AGENT_SIGNING_DOMAIN="${AGENT_SIGNING_DOMAIN:-noreply.${machine}.local}"

mkdir -p "$(dirname "${ALLOWED_SIGNERS}")"

for harness in "${HARNESSES[@]}"; do
    pubkey="${KEY_DIR}/${harness}.pub"
    if [[ ! -f "${pubkey}" ]]; then
        echo "skip:agent-signing (no key at ${pubkey} — run scripts/install/agent-signing-keys.sh)"
        continue
    fi
    entry="${harness}@${AGENT_SIGNING_DOMAIN} $(awk '{print $1, $2}' "${pubkey}")"
    if [[ -f "${ALLOWED_SIGNERS}" ]] && grep -qxF "${entry}" "${ALLOWED_SIGNERS}"; then
        echo "skip:allowed_signers (${harness} already entered)"
    else
        echo "${entry}" >> "${ALLOWED_SIGNERS}"
        echo "append:allowed_signers (${harness}@${AGENT_SIGNING_DOMAIN})"
    fi
done

echo "ok:agent-signing"
