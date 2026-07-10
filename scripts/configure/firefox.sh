#!/bin/bash
# Harden the active Firefox profile by deploying manifests/firefox/user.js into
# it. Run AFTER launching Firefox and signing into Sync — the profile must exist
# and be populated first. Firefox reads user.js at every startup and copies its
# prefs into prefs.js, so restart Firefox to apply.
#
# Profile detection prefers installs.ini's Default= (the profile the browser
# actually launches), falling back to the *.default-release directory. An
# existing hand-written user.js is backed up once to user.js.bak before the
# forge copy lands; a matching copy is a no-op.
# Reference: https://github.com/arkenfox/user.js
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

FIREFOX_DIR="${HOME}/Library/Application Support/Firefox"
MANIFEST_FILE="${FORGE_PROVISION_ROOT}/manifests/firefox/user.js"

if [[ ! -d "/Applications/Firefox.app" ]]; then
    echo "fail:firefox (Firefox not installed; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "fail:firefox (manifest missing at ${MANIFEST_FILE})"
    exit 1
fi

resolve_profile() {
    local relative
    if [[ -f "${FIREFOX_DIR}/installs.ini" ]]; then
        relative=$(grep -m1 '^Default=' "${FIREFOX_DIR}/installs.ini" | cut -d= -f2-)
        if [[ -n "${relative}" && -d "${FIREFOX_DIR}/${relative}" ]]; then
            echo "${FIREFOX_DIR}/${relative}"
            return 0
        fi
    fi
    local fallback
    fallback=$(find "${FIREFOX_DIR}/Profiles" -maxdepth 1 -type d -name '*.default-release' 2>/dev/null | head -1)
    [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
    return 1
}

PROFILE=$(resolve_profile)
if [[ -z "${PROFILE}" ]]; then
    echo "fail:firefox (no profile found; launch Firefox and sign into Sync first)"
    exit 1
fi

DEPLOYED_FILE="${PROFILE}/user.js"

if [[ -f "${DEPLOYED_FILE}" ]] && cmp -s "${MANIFEST_FILE}" "${DEPLOYED_FILE}"; then
    echo "skip:firefox (user.js already current in $(basename "${PROFILE}"))"
    echo "ok:firefox"
    exit 0
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "dry-run:firefox (would deploy user.js to $(basename "${PROFILE}"))"
    exit 0
fi

if [[ -f "${DEPLOYED_FILE}" && ! -f "${DEPLOYED_FILE}.bak" ]]; then
    echo "backup:firefox (user.js -> user.js.bak)"
    cp "${DEPLOYED_FILE}" "${DEPLOYED_FILE}.bak"
fi

echo "deploy:firefox (user.js -> $(basename "${PROFILE}"))"
cp "${MANIFEST_FILE}" "${DEPLOYED_FILE}" || { echo "fail:firefox (copy failed)"; exit 1; }
echo "ok:firefox"
echo "      restart Firefox to apply; aggressive prefs are commented in user.js"
