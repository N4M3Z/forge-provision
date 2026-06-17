#!/bin/bash
# Hide the ~/OrbStack file-sharing mount point from Finder.
# OrbStack hardcodes ~/OrbStack as its NFS view and does not support relocating
# it (orbstack/orbstack#239). The UF_HIDDEN flag persists across remounts, so
# setting it once keeps the folder out of Finder for good. It can only be set
# while the folder is a plain directory (OrbStack stopped); a live NFS mount
# rejects chflags. Idempotent — skips when absent, mounted, or already hidden.
# Reference: https://github.com/orbstack/orbstack/issues/239
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FOLDER="${HOME}/OrbStack"

if [[ ! -e "${FOLDER}" ]]; then
    echo "skip:orbstack-hide (no ${FOLDER}; OrbStack has not created it yet)"
    exit 0
fi

if mount | grep -q "on ${FOLDER} "; then
    echo "skip:orbstack-hide (live mount; stop OrbStack first to set the flag)"
    exit 0
fi

if [[ "$(stat -f '%Sf' "${FOLDER}" 2>/dev/null)" == *hidden* ]]; then
    echo "skip:orbstack-hide (already hidden)"
    exit 0
fi

echo "configure:orbstack-hide"
chflags hidden "${FOLDER}"
