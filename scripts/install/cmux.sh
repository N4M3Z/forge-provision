#!/bin/bash
# Install cmux from the canonical-latest DMG. cmux is intentionally NOT in
# Brewfile (see manifests/Brewfile tombstone comment) — Homebrew's `brew
# upgrade --cask cmux` would silently overwrite a known-good version.
# Manual install via this script keeps us in control.
#
# Idempotent: skips if /Applications/cmux.app already exists. Force a
# reinstall by deleting the app first or passing --force.
#
# After install, run `cmux hooks setup` manually once to wire Claude Code
# lifecycle hooks into ~/.claude/settings.json.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CMUX_APP="/Applications/cmux.app"
CMUX_SYMLINK="${HOME}/.local/bin/cmux"
CMUX_DMG_URL="https://github.com/manaflow-ai/cmux/releases/latest/download/cmux-macos.dmg"
CMUX_DMG_TMP="$(command mktemp -t cmux-install-XXXXXX).dmg"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ -d "${CMUX_APP}" && ${FORCE} -eq 0 ]]; then
    echo "skip:cmux (${CMUX_APP} already installed; pass --force to reinstall)"
    exit 0
fi

trap 'rm -f "${CMUX_DMG_TMP}"' EXIT

echo "fetch:cmux (latest DMG from ${CMUX_DMG_URL})"
command curl -fL --progress-bar -o "${CMUX_DMG_TMP}" "${CMUX_DMG_URL}" || {
    echo "fail:cmux (download failed)"
    exit 1
}

echo "mount:cmux-recovery"
MOUNT_POINT=$(command hdiutil attach "${CMUX_DMG_TMP}" -nobrowse -quiet -mountrandom /tmp 2>/dev/null | \
    command awk '/\/Volumes/ {print $NF; exit}' | command tr -d '[:space:]')
if [[ -z "${MOUNT_POINT}" || ! -d "${MOUNT_POINT}/cmux.app" ]]; then
    echo "fail:cmux (DMG mount failed or no cmux.app inside)"
    exit 1
fi

if [[ -d "${CMUX_APP}" ]]; then
    echo "remove:${CMUX_APP} (force-reinstall)"
    command rm -rf "${CMUX_APP}"
fi

echo "copy:cmux.app -> /Applications"
command cp -R "${MOUNT_POINT}/cmux.app" /Applications/ || {
    command hdiutil detach "${MOUNT_POINT}" -quiet
    echo "fail:cmux (copy to /Applications failed)"
    exit 1
}

command hdiutil detach "${MOUNT_POINT}" -quiet

if ! [[ -d "${CMUX_APP}" ]]; then
    echo "fail:cmux (${CMUX_APP} not present after copy)"
    exit 1
fi

echo "verify:code-signature"
command codesign --verify --quiet "${CMUX_APP}" 2>&1 || {
    echo "warn:cmux (code signature verification failed — proceed with caution)"
}

command mkdir -p "$(command dirname "${CMUX_SYMLINK}")"
command ln -sf "${CMUX_APP}/Contents/Resources/bin/cmux" "${CMUX_SYMLINK}"
echo "link:${CMUX_SYMLINK} -> ${CMUX_APP}/Contents/Resources/bin/cmux"

if command -v cmux >/dev/null 2>&1; then
    echo "ok:cmux ($(command cmux --version 2>&1 | command head -1))"
    echo "      next: launch cmux from /Applications, then run \`cmux hooks setup\`"
    echo "            to wire Claude Code lifecycle hooks into ~/.claude/settings.json"
else
    echo "warn:cmux installed but CLI not on PATH (expected ~/.local/bin in PATH)"
fi
