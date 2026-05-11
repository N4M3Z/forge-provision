#!/bin/bash
# Migrate Claude Code chat history from the old Mac.
# Copies only `projects/` and `history.jsonl` from ${OLD_CLAUDE_DIR} to ${NEW_CLAUDE_DIR}.
# Everything else (agents, skills, rules, plugins, hooks, settings.json) rebuilds via forge-* deploy.
# Idempotent (rsync).
#
# CAVEATS:
# - Does NOT touch ~/.claude.json at home root (plaintext OAuth/MCP tokens; the new Mac has its own).
# - Claude Code 2.1.9+ blocks cross-machine /resume — transcripts are still readable as files but
#   the UI may show "No conversation found to continue". The .jsonl files themselves remain usable.
# - Project dirs are path-encoded; transcripts only surface in /resume when working directories
#   on the new Mac match those on the old Mac.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ -z "${OLD_CLAUDE_DIR}" || ! -d "${OLD_CLAUDE_DIR}" ]]; then
    echo "fail:claude-history (OLD_CLAUDE_DIR not set or not a directory: ${OLD_CLAUDE_DIR})"
    echo "      set OLD_MAC_MOUNT in .env to your old Mac's mount path (e.g. /Volumes/N4M3Z)"
    exit 1
fi

if [[ ! -d "${OLD_CLAUDE_DIR}/projects" ]]; then
    echo "fail:claude-history (no projects/ under ${OLD_CLAUDE_DIR})"
    exit 1
fi

# Prefer Homebrew rsync over the Apple-shipped openrsync 2.6.9-compatible, which
# does not support --info=progress2 and other modern flags. brew install rsync.
RSYNC=/opt/homebrew/bin/rsync
[[ -x "${RSYNC}" ]] || RSYNC=/usr/local/bin/rsync
if [[ ! -x "${RSYNC}" ]]; then
    echo "fail:claude-history (modern rsync 3+ required — install via: brew install rsync)"
    exit 1
fi

mkdir -p "${NEW_CLAUDE_DIR}/projects"

echo "rsync:projects/"
"${RSYNC}" -a --info=progress2 "${OLD_CLAUDE_DIR}/projects/" "${NEW_CLAUDE_DIR}/projects/" || {
    echo "fail:rsync projects/"
    exit 1
}

if [[ -f "${OLD_CLAUDE_DIR}/history.jsonl" ]]; then
    echo "rsync:history.jsonl"
    "${RSYNC}" -a "${OLD_CLAUDE_DIR}/history.jsonl" "${NEW_CLAUDE_DIR}/history.jsonl"
fi

echo "ok:claude-history"
echo "      ~/.claude.json at home root left untouched (contains plaintext tokens)"
