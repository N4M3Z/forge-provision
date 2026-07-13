#!/usr/bin/env bash
# Migrate SuperWhisper between machines. Three stores, one command:
#
#   1. Prefs plist   Library/Preferences/com.superduper.superwhisper.plist
#                    -> defaults import (settings, hotkeys, appFolderDirectory, account)
#   2. History DB    Library/Application Support/superwhisper/database/
#                    -> rsync (transcription history + full-text-search index)
#   3. Sync folder   <appFolderDirectory>, default ${VOICE_DIR}/superwhisper
#                    -> rsync minus models/ (recordings, modes, settings, replacements)
#
# Skipped: the whisper/LLM models (App Support *.gguf / *.bin / *.onnx and the
# Data/Voice models/ subdir). Multi-GB, re-downloaded in-app.
#
# Dictionary caveat: SuperWhisper's vocabulary lives in the Pro cloud account,
# NOT in these files. On a machine that isn't logged in (licenseValid=0) only the
# default vocabulary appears even after a clean migration. Restore it by logging
# into SuperWhisper, or cross-import MacWhisper's local dictionary as a one-off:
# read the source MacWhisper plist key dictationDictionaryStrings, extract each
# {"text":...}, and merge into this sync folder's settings/settings.json
# "vocabulary" array (dedup). Do it with SuperWhisper quit, since the running app
# rewrites settings.json from memory on quit.
#
# Why quit first: cfprefsd caches the plist, the sqlite DB must not be open, and
# the running app clobbers settings.json from memory on quit. The script quits
# SuperWhisper before touching anything.
#
# Usage:
#   bash superwhisper.sh [SRC_HOME]
#     SRC_HOME  mounted source home dir (default ${MIGRATE_SRC})
#
# Idempotent (rsync skips unchanged). Skips gracefully when a source is absent.
# Supports DRY_RUN. Plist import backs up the current plist first.
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

BUNDLE="com.superduper.superwhisper"
SRC_HOME="${1:-${MIGRATE_SRC:-}}"
DST_VOICE="${VOICE_DIR:-${HOME}/Data/Voice}/superwhisper"

SRC_PLIST="${SRC_HOME}/Library/Preferences/${BUNDLE}.plist"
SRC_DB="${SRC_HOME}/Library/Application Support/superwhisper/database"
SRC_VOICE="${SRC_HOME}/Data/Voice/superwhisper"

DST_PLIST="${HOME}/Library/Preferences/${BUNDLE}.plist"
DST_DB="${HOME}/Library/Application Support/superwhisper/database"

echo "migrate:superwhisper"

if [[ -z "${SRC_HOME}" ]]; then
    echo "skip:superwhisper (no source — set MIGRATE_SRC in .env or pass SRC_HOME as arg 1)"
    exit 0
fi
if [[ ! -d "${SRC_HOME}" ]]; then
    echo "skip:superwhisper (source home not found at ${SRC_HOME})"
    exit 0
fi

# Quit the app: plist is cfprefsd-cached, the DB must not be open, and the
# running app rewrites settings.json from memory on quit.
if [[ -z "${DRY_RUN:-}" ]]; then
    osascript -e 'quit app "superwhisper"' 2>/dev/null || true
    sleep 1
fi

# --- 1. Prefs plist -> defaults import ---------------------------------------
if [[ -f "${SRC_PLIST}" ]]; then
    if [[ -n "${DRY_RUN:-}" ]]; then
        echo "  would: back up ${DST_PLIST}, then defaults import ${BUNDLE} from source"
    else
        if [[ -f "${DST_PLIST}" ]]; then
            cp "${DST_PLIST}" "${DST_PLIST}.pre-migrate.bak" 2>/dev/null && \
                echo "backup:${DST_PLIST}.pre-migrate.bak"
        fi
        if defaults import "${BUNDLE}" "${SRC_PLIST}" 2>/dev/null; then
            echo "ok:superwhisper-plist (settings imported; re-login if Pro shows inactive)"
        else
            echo "warn:superwhisper-plist (defaults import failed)"
        fi
    fi
else
    echo "skip:superwhisper-plist (no source plist at ${SRC_PLIST})"
fi

# --- 2. History database -> rsync -------------------------------------------
if [[ -d "${SRC_DB}" ]]; then
    if [[ -n "${DRY_RUN:-}" ]]; then
        echo "  would rsync ${SRC_DB}/ -> ${DST_DB}/"
    else
        mkdir -p "${DST_DB}"
        if "${RSYNC}" -a "${SRC_DB}/" "${DST_DB}/"; then
            echo "ok:superwhisper-db (history + search index)"
        else
            echo "warn:superwhisper-db (rsync error)"
        fi
    fi
else
    echo "skip:superwhisper-db (no source database at ${SRC_DB})"
fi

# --- 3. Sync folder (recordings, modes, settings) -> rsync minus models ------
if [[ -d "${SRC_VOICE}" ]]; then
    if [[ -n "${DRY_RUN:-}" ]]; then
        echo "  would rsync ${SRC_VOICE}/ -> ${DST_VOICE}/ (excluding models/)"
    else
        mkdir -p "${DST_VOICE}"
        if "${RSYNC}" -a --info=progress2 --exclude='models/' "${SRC_VOICE}/" "${DST_VOICE}/"; then
            echo "ok:superwhisper-voice (recordings, modes, settings at ${DST_VOICE})"
        else
            echo "warn:superwhisper-voice (rsync error)"
        fi
    fi
else
    echo "skip:superwhisper-voice (no source sync folder at ${SRC_VOICE})"
fi

echo "ok:superwhisper (launch the app; verify history + recordings; dictionary needs Pro login or MacWhisper cross-import — see header)"
