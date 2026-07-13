#!/usr/bin/env bash
# Migrate MacWhisper preferences between two machines.
#
# Usage:
#   bash macwhisper.sh [SRC] [DST]
#     SRC  source prefs plist   (default ${MIGRATE_SRC}/Library/Preferences/com.goodsnooze.MacWhisper.plist)
#     DST  destination plist    (default ~/Library/Preferences/com.goodsnooze.MacWhisper.plist)
#
# Portable vs machine-local:
#   Preferences/com.goodsnooze.MacWhisper.plist        <- migrated (config)
#   Application Support/com.goodsnooze.MacWhisper/      <- skipped (license
#       cache, logs, queue, anonymous IDs — machine-local, not portable)
#
# Models are re-downloaded in-app or relocated to ${VOICE_DIR}/macwhisper via
# MacWhisper's own settings, so no model bytes move through this script.
#
# The plist mixes user settings with license state and machine identifiers.
# Importing it over a machine that already launched MacWhisper can clobber the
# new machine's license/identity. The script refuses to overwrite an existing
# DST unless FORCE=1, so the safe path is: run before first launch, or diff
# manually.
#
# Idempotent. Skips gracefully when SRC is absent. Supports DRY_RUN and FORCE.
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full
[[ -f "${SCRIPT_DIR}/../lib/helpers.sh" ]] && source "${SCRIPT_DIR}/../lib/helpers.sh"

# rsync 3+ required (PROV-0001). Apple ships openrsync; brew lands modern.
RSYNC="/opt/homebrew/bin/rsync"
[[ -x "${RSYNC}" ]] || RSYNC="$(command -v rsync)"

BUNDLE="com.goodsnooze.MacWhisper"
SRC="${1:-${MIGRATE_SRC:-}/Library/Preferences/${BUNDLE}.plist}"
DST="${2:-${HOME}/Library/Preferences/${BUNDLE}.plist}"

echo "migrate:macwhisper"

if [[ ! -f "${SRC}" ]]; then
    echo "skip:macwhisper (source prefs not found at ${SRC})"
    echo "      mount the source machine and set MIGRATE_SRC in .env, or pass SRC as arg 1"
    exit 0
fi

if [[ -f "${DST}" && -z "${FORCE:-}" ]]; then
    echo "skip:macwhisper (dest prefs already exist: ${DST})"
    echo "      MacWhisper has run on this machine. Diff manually, or re-run with FORCE=1"
    echo "      to overwrite (clobbers this machine's license/identity keys)."
    exit 0
fi

if [[ -n "${DRY_RUN:-}" ]]; then
    echo "  would copy ${SRC} -> ${DST}"
    echo "skip:macwhisper (dry-run)"
    exit 0
fi

# Preferences are cached by cfprefsd; quit the app before importing.
osascript -e 'quit app "MacWhisper"' 2>/dev/null || true

"${RSYNC}" -a "${SRC}" "${DST}" || {
    echo "fail:macwhisper (rsync error)"
    exit 0
}
defaults read "${BUNDLE}" >/dev/null 2>&1 || true

echo "ok:macwhisper (prefs migrated; relaunch MacWhisper, re-point model store"
echo "      to ${VOICE_DIR:-~/Data/Voice}/macwhisper, re-download or relocate models)"
