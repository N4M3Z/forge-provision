#!/usr/bin/env bash
# Migrate MacWhisper DATA between machines. Settings are not migrated here:
# they deploy as a curated plist from the dotfiles repo (chezmoi
# run_onchange_after_macwhisper.sh applies `defaults import`), which carries
# user intent (prompts, dictation dictionary, export formats, AI-service
# metadata) and never machine state or the raw plist's embedded app-icon blobs.
#
# What moves, from the source home dir:
#   Library/Application Support/MacWhisper/Database/   -> rsync --delete
#       main.sqlite + WAL (sessions, transcripts, meetings) and
#       ExternalMedia/ (the recorded meetings' audio — the bulk of the bytes)
#   Library/Application Support/MacWhisper/RecordedMeetings/ -> rsync, if present
#
# Path trap: this is the NON-sandboxed location. A machine may also carry
# Library/Containers/com.goodsnooze.MacWhisper/ with its own
# Application Support/MacWhisper/Database — that is a stale sandboxed-era
# install with an old empty schema. Never migrate the container copy.
#
# Skipped on purpose:
#   models under Application Support/MacWhisper/models and the
#   Library/Caches/argmax-sdk-swift model cache (multi-GB, re-downloaded
#   in-app on demand)
#   license + API keys (macOS Keychain; re-enter once on the new machine)
#
# Count caveat when verifying: query the copied DB with plain read-only mode,
# not immutable=1 — immutable ignores the WAL, which may hold the app's last
# not-yet-checkpointed deletions, so it overcounts.
#
# Usage:
#   bash macwhisper.sh [SRC_HOME]
#     SRC_HOME  mounted source home dir (default ${MIGRATE_SRC})
#
# Idempotent (rsync skips unchanged). Skips gracefully when the source is
# absent. Supports DRY_RUN. A non-empty destination Database is backed up
# once per day (Database.YYYY-MM-DD.bak) before --delete replaces it.
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

SRC_HOME="${1:-${MIGRATE_SRC:-}}"
SRC_APP="${SRC_HOME}/Library/Application Support/MacWhisper"
DST_APP="${HOME}/Library/Application Support/MacWhisper"

echo "migrate:macwhisper"

if [[ ! -d "${SRC_APP}/Database" ]]; then
    echo "skip:macwhisper (no source Database at ${SRC_APP})"
    echo "      mount the source machine and set MIGRATE_SRC in .env, or pass SRC_HOME as arg 1"
    exit 0
fi

if [[ -n "${DRY_RUN:-}" ]]; then
    echo "  would rsync '${SRC_APP}/Database/' -> '${DST_APP}/Database/' (with --delete)"
    [[ -d "${SRC_APP}/RecordedMeetings" ]] && \
        echo "  would rsync '${SRC_APP}/RecordedMeetings/' -> '${DST_APP}/RecordedMeetings/'"
    echo "skip:macwhisper (dry-run)"
    exit 0
fi

# The sqlite database must not be open during the copy.
osascript -e 'quit app "MacWhisper"' 2>/dev/null || true

mkdir -p "${DST_APP}"

backup="${DST_APP}/Database.$(date -u +%Y-%m-%d).bak"
if [[ -d "${DST_APP}/Database" && ! -d "${backup}" ]] \
    && [[ -n "$(ls "${DST_APP}/Database" 2>/dev/null)" ]]; then
    echo "backup:${backup}"
    cp -R "${DST_APP}/Database" "${backup}"
fi

echo "copy:Database (sessions, transcripts, meeting audio)"
"${RSYNC}" -a --delete "${SRC_APP}/Database/" "${DST_APP}/Database/" || {
    echo "fail:macwhisper (Database rsync error)"
    exit 1
}

if [[ -d "${SRC_APP}/RecordedMeetings" ]]; then
    echo "copy:RecordedMeetings"
    "${RSYNC}" -a "${SRC_APP}/RecordedMeetings/" "${DST_APP}/RecordedMeetings/" || {
        echo "fail:macwhisper (RecordedMeetings rsync error)"
        exit 1
    }
fi

sessions="$(sqlite3 "file:${DST_APP}/Database/main.sqlite?mode=ro" \
    'SELECT COUNT(*) FROM session;' 2>/dev/null || echo '?')"
echo "ok:macwhisper (${sessions} sessions migrated; settings deploy via dotfiles chezmoi,"
echo "      license + API keys re-enter once from Keychain, models re-download in-app)"
