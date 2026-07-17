#!/bin/bash
# Verify the signing lanes are wired: alerter for the summons, the launchd
# schedule loaded, per-harness agent keys present, and allowed_signers
# covering them for local verification.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

HARNESSES=(claude codex grok antigravity opencode)
KEY_DIR="${AGENT_SIGNING_KEY_DIR:-${HOME}/.ssh}"
ALLOWED_SIGNERS="${HOME}/.config/git/allowed_signers"
LABEL="com.n4m3z.sign"
failures=0

if command -v alerter >/dev/null 2>&1; then
    echo "ok:sign (alerter installed)"
else
    echo "fail:sign (alerter missing — brew bundle installs vjeantet/tap/alerter)"
    failures=$((failures + 1))
fi

if launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
    echo "ok:sign (LaunchAgent ${LABEL} loaded)"
else
    echo "fail:sign (LaunchAgent ${LABEL} not loaded — chezmoi apply wires it)"
    failures=$((failures + 1))
fi

for harness in "${HARNESSES[@]}"; do
    if [[ ! -f "${KEY_DIR}/${harness}" ]]; then
        echo "fail:sign (no signing key for ${harness} — run scripts/install/agent-signing-keys.sh)"
        failures=$((failures + 1))
        continue
    fi
    if [[ -f "${ALLOWED_SIGNERS}" ]] \
        && grep -qF "$(awk '{print $1, $2}' "${KEY_DIR}/${harness}.pub")" "${ALLOWED_SIGNERS}"; then
        echo "ok:sign (${harness} key present and in allowed_signers)"
    else
        echo "warn:sign (${harness} key not in allowed_signers — run scripts/configure/agent-signing.sh)"
    fi
done

exit "$(( failures > 0 ? 1 : 0 ))"
