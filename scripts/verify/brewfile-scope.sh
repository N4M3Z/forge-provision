#!/bin/bash
# Verify manifests/Brewfile.work is a strict subset of manifests/Brewfile.
# An entry present only in the work manifest either drifted or was fat-fingered;
# the full Brewfile is the single source of truth for what a tool is and why.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FULL="${FORGE_PROVISION_ROOT}/manifests/Brewfile"
WORK="${FORGE_PROVISION_ROOT}/manifests/Brewfile.work"

if [[ ! -f "${WORK}" ]]; then
    echo "skip:brewfile-scope (no Brewfile.work)"
    exit 0
fi

entries() { awk '/^(brew|cask|tap|mas) /' "$1" | tr -s ' ' | sed 's/[[:space:]]*$//' | sort -u; }

orphans=$(comm -23 <(entries "${WORK}") <(entries "${FULL}"))

if [[ -n "${orphans}" ]]; then
    echo "fail:brewfile-scope (entries in Brewfile.work missing from Brewfile):"
    printf '      %s\n' ${orphans:+"${orphans}"}
    exit 1
fi

echo "ok:brewfile-scope ($(entries "${WORK}" | wc -l | tr -d ' ') work entries, all present in Brewfile)"
