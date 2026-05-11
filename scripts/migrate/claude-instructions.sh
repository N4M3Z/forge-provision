#!/bin/bash
# Migrate top-level Claude Code instruction files from the old Mac.
# Copies any `.md` at ${OLD_CLAUDE_DIR}/ root (typically CLAUDE.md, GitConventions.md, RTK.md)
# into ${NEW_CLAUDE_DIR}/. Skips any destination file that already exists (assumes user has
# customised it). Idempotent.
#
# Note: these are SEPARATE from per-project auto-memory at projects/<path>/memory/* which
# `scripts/migrate/claude-history.sh` already covers.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ -z "${OLD_CLAUDE_DIR}" || ! -d "${OLD_CLAUDE_DIR}" ]]; then
    echo "fail:claude-instructions (OLD_CLAUDE_DIR not set or not a directory: ${OLD_CLAUDE_DIR})"
    exit 1
fi

mkdir -p "${NEW_CLAUDE_DIR}"

shopt -s nullglob
copied=0
skipped=0
for src in "${OLD_CLAUDE_DIR}"/*.md; do
    f="$(basename "$src")"
    dest="${NEW_CLAUDE_DIR}/${f}"
    if [[ -f "${dest}" ]]; then
        echo "skip:${f} (exists)"
        skipped=$((skipped + 1))
    else
        cp "$src" "$dest"
        echo "copy:${f}"
        copied=$((copied + 1))
    fi
done

echo "ok:claude-instructions (copied=${copied} skipped=${skipped})"
