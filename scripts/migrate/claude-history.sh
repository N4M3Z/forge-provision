#!/bin/bash
# Migrate Claude Code chat history from an old Mac, over a mounted volume or SSH.
#
# Two-stage: the old store lands verbatim in the archive layer first
# (~/Data/Imports/<label>/), then new session files merge into the live
# store. The archive copy is the durable record; the merge is what makes the
# existing capture pipeline (SpecStory markdown, session-sync raw preserve,
# memsearch index) pick the sessions up on its next sweep.
#
# Source selection: OLD_MAC_MOUNT (network volume) wins when set; otherwise
# OLD_MAC_SSH (user@host with Remote Login enabled) pulls over rsync/ssh.
#
# CAVEATS:
# - Does NOT touch ~/.claude.json at home root (plaintext OAuth/MCP tokens; the new Mac has its own).
# - The old machine's history.jsonl stays in the archive only: merging it would splice
#   another machine's prompt history into this one's /resume picker.
# - Claude Code 2.1.9+ blocks cross-machine /resume — transcripts are still readable as files but
#   the UI may show "No conversation found to continue". The .jsonl files themselves remain usable.
# - The merge is additive (--ignore-existing) and every merged file is listed in the
#   manifest beside the archive, so it can be reversed file-by-file.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

# Prefer Homebrew rsync over the Apple-shipped openrsync 2.6.9-compatible, which
# does not support --info=progress2 and other modern flags. brew install rsync.
RSYNC=/opt/homebrew/bin/rsync
[[ -x "${RSYNC}" ]] || RSYNC=/usr/local/bin/rsync
if [[ ! -x "${RSYNC}" ]]; then
    echo "fail:claude-history (modern rsync 3+ required — install via: brew install rsync)"
    exit 1
fi

if [[ -n "${OLD_MAC_MOUNT}" && -d "${OLD_CLAUDE_DIR}" ]]; then
    SOURCE="${OLD_CLAUDE_DIR}/"
    LABEL="$(basename "${OLD_MAC_MOUNT}")"
elif [[ -n "${OLD_MAC_SSH:-}" ]]; then
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${OLD_MAC_SSH}" true 2>/dev/null; then
        echo "fail:claude-history (ssh ${OLD_MAC_SSH} unreachable — enable Remote Login on the old Mac:"
        echo "      System Settings > General > Sharing > Remote Login)"
        exit 1
    fi
    SOURCE="${OLD_MAC_SSH}:.claude/"
    LABEL="${OLD_MAC_SSH##*@}"
else
    echo "fail:claude-history (set OLD_MAC_MOUNT or OLD_MAC_SSH in .env)"
    exit 1
fi

ARCHIVE="${HOME}/Data/Imports/${LABEL}"
MANIFEST="${ARCHIVE}/merged-into-live-store.txt"
mkdir -p "${ARCHIVE}"

echo "rsync:archive (${SOURCE}projects -> ${ARCHIVE}/projects)"
"${RSYNC}" -a --info=progress2 \
    --include='projects/***' --include='history.jsonl' --exclude='*' \
    "${SOURCE}" "${ARCHIVE}/" || {
    echo "fail:claude-history (archive rsync)"
    exit 1
}

if [[ ! -d "${ARCHIVE}/projects" ]]; then
    echo "fail:claude-history (no projects/ arrived under ${ARCHIVE})"
    exit 1
fi

echo "rsync:merge (archive -> ${NEW_CLAUDE_DIR}/projects, new files only)"
mkdir -p "${NEW_CLAUDE_DIR}/projects"
"${RSYNC}" -a --ignore-existing --itemize-changes \
    "${ARCHIVE}/projects/" "${NEW_CLAUDE_DIR}/projects/" \
    | awk '/^>f/ { print $2 }' > "${MANIFEST}" || {
    echo "fail:claude-history (merge rsync)"
    exit 1
}

merged="$(wc -l < "${MANIFEST}" | tr -d ' ')"
echo "ok:claude-history (archive at ${ARCHIVE}; ${merged} files merged, manifest ${MANIFEST})"
echo "      ~/.claude.json at home root left untouched (contains plaintext tokens)"
echo "      next session-sync sweep converts and indexes the imported sessions"
