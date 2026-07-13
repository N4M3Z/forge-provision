#!/bin/bash
# Install the oMLX inference server from its macOS .dmg (the menu-bar app) and
# symlink the bundled CLI. Idempotent: skips when /Applications/oMLX.app is
# present; pass --force to reinstall over it.
#
# oMLX is the local MLX inference tier for Apple Silicon: it serves MLX-format
# LLMs, VLMs, embedding models, and rerankers on localhost:8000 behind an
# OpenAI-compatible API, so an editor's inline assist, RAG, and agents can run
# fully offline. Its differentiator over the GGUF runners (Ollama, LM Studio) is
# a tiered RAM+SSD KV cache that persists and reuses context across requests,
# plus continuous batching -- the win shows on long-context and repeated-prefix
# work, not raw decode. Models are discovered from ~/.omlx/models.
#
# The .app (native menu-bar server) is the daily-driver lane; the Homebrew
# formula (`brew install jundot/omlx/omlx`) is the headless alternative. Both
# bind :8000 and share ~/.omlx/, so exactly one server runs at a time: if the
# formula service is installed, `brew services stop jundot/omlx/omlx` frees the
# port for the app. On first launch the app installs its CLI shim at
# ~/.omlx/bin/omlx (sets OMLX_BASE_PATH, then execs the bundled omlx-cli);
# ~/.local/bin/omlx symlinks the shim when present, else the bundle binary.
#
# The DMG asset name embeds both the release version and the macOS major
# (`oMLX-<version>-macos15-sequoia.dmg` vs `oMLX-<version>-macos26-27.dmg`), so
# there is no stable canonical-latest URL. The download URL is resolved at run
# time from the GitHub releases API by matching the running macOS major.
#
# Pulling models is application setup, not base provisioning, so it is left out:
# fetch an MLX model into ~/.omlx/models via the admin dashboard downloader
# (http://localhost:8000/admin) or an mlx-community repo.
#
# Reference: https://github.com/jundot/omlx
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

OMLX_APP="/Applications/oMLX.app"
OMLX_SYMLINK="${HOME}/.local/bin/omlx"
OMLX_RELEASES_API="https://api.github.com/repos/jundot/omlx/releases/latest"
OMLX_DMG_TMP="$(command mktemp -t omlx-install-XXXXXX).dmg"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ -d "${OMLX_APP}" && ${FORCE} -eq 0 ]]; then
    echo "skip:omlx (${OMLX_APP} already installed; pass --force to reinstall)"
    exit 0
fi

macos_major="$(command sw_vers -productVersion | command cut -d. -f1)"
if (( macos_major >= 26 )); then
    dmg_suffix="macos26-27"
else
    dmg_suffix="macos15-sequoia"
fi

echo "resolve:omlx (latest ${dmg_suffix} DMG)"
dmg_url="$(command curl -fsSL "${OMLX_RELEASES_API}" \
    | command grep -oE "https://[^\"]*${dmg_suffix}\.dmg" | command head -1)"
if [[ -z "${dmg_url}" ]]; then
    echo "fail:omlx (no ${dmg_suffix} DMG in latest release)"
    exit 1
fi

trap 'command rm -f "${OMLX_DMG_TMP}"' EXIT

echo "fetch:omlx (${dmg_url})"
command curl -fL --progress-bar -o "${OMLX_DMG_TMP}" "${dmg_url}" || {
    echo "fail:omlx (download failed)"
    exit 1
}

echo "mount:omlx"
# -mountrandom /tmp mounts at /tmp/dmg.XXXXXX; the mount point is the last
# field of the attach line that carries one.
mount_point="$(command hdiutil attach "${OMLX_DMG_TMP}" -nobrowse -quiet -mountrandom /tmp 2>/dev/null | \
    command awk '$NF ~ /^\/tmp\// {print $NF; exit}' | command tr -d '[:space:]')"
if [[ -z "${mount_point}" ]]; then
    echo "fail:omlx (DMG mount failed)"
    exit 1
fi
if [[ ! -d "${mount_point}/oMLX.app" ]]; then
    command hdiutil detach "${mount_point}" -quiet
    echo "fail:omlx (no oMLX.app inside DMG)"
    exit 1
fi

if [[ -d "${OMLX_APP}" ]]; then
    echo "remove:${OMLX_APP} (force-reinstall)"
    command rm -rf "${OMLX_APP}"
fi

echo "copy:oMLX.app -> /Applications"
command cp -R "${mount_point}/oMLX.app" /Applications/ || {
    command hdiutil detach "${mount_point}" -quiet
    echo "fail:omlx (copy to /Applications failed)"
    exit 1
}

command hdiutil detach "${mount_point}" -quiet

command codesign --verify --quiet "${OMLX_APP}" 2>&1 || {
    echo "fail:omlx (code signature verification failed -- refusing to symlink an unverified app)"
    command rm -rf "${OMLX_APP}"
    exit 1
}

command mkdir -p "$(command dirname "${OMLX_SYMLINK}")"
if [[ -x "${HOME}/.omlx/bin/omlx" ]]; then
    command ln -sf "${HOME}/.omlx/bin/omlx" "${OMLX_SYMLINK}"
else
    command ln -sf "${OMLX_APP}/Contents/MacOS/omlx-cli" "${OMLX_SYMLINK}"
fi

echo "ok:omlx (${OMLX_APP} installed, omlx -> $(command readlink "${OMLX_SYMLINK}"))"
echo "      next: launch oMLX from /Applications to start the :8000 server (menu bar),"
echo "            then pull a model via the admin dashboard (http://localhost:8000/admin)."
if command brew services list 2>/dev/null | command grep -qE 'omlx[[:space:]].*started'; then
    echo "      one server at a time: the formula service holds :8000 -- free it with"
    echo "      \`brew services stop jundot/omlx/omlx\` before the app can bind."
fi
