#!/bin/bash
# Migrate rtk state (filters.toml + history.db + tee/) from the old Mac.
# Source: ${OLD_MAC_MOUNT}/Library/Application Support/rtk/
# Destination: ${HOME}/Library/Application Support/rtk/
# Idempotent — rsync skips unchanged files.
# Reference: https://github.com/rtk-ai/rtk
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ -z "${OLD_MAC_MOUNT}" || ! -d "${OLD_MAC_MOUNT}" ]]; then
    echo "fail:rtk-state (OLD_MAC_MOUNT not set or not a directory: ${OLD_MAC_MOUNT})"
    exit 1
fi

SRC="${OLD_MAC_MOUNT}/Library/Application Support/rtk"
DEST="${HOME}/Library/Application Support/rtk"

if [[ ! -d "${SRC}" ]]; then
    echo "fail:rtk-state (no rtk state under ${SRC})"
    exit 1
fi

# Prefer Homebrew rsync over Apple's openrsync 2.6.9-compatible (PROV-0001).
RSYNC=/opt/homebrew/bin/rsync
[[ -x "${RSYNC}" ]] || RSYNC=/usr/local/bin/rsync
if [[ ! -x "${RSYNC}" ]]; then
    echo "fail:rtk-state (modern rsync 3+ required — brew install rsync)"
    exit 1
fi

mkdir -p "${DEST}"

echo "rsync:rtk-state"
"${RSYNC}" -a "${SRC}/" "${DEST}/" || {
    echo "fail:rsync rtk-state"
    exit 1
}

echo "ok:rtk-state"
ls -lh "${DEST}/" | head
