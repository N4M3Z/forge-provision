#!/bin/bash
# Seed Zed config from manifests/zed/ on first provision: settings.jsonc,
# keymap.jsonc, and tasks.jsonc deployed as the matching .json files in
# ~/.config/zed/, plus snippets/markdown.json, only when absent (sources carry
# comments, so they live as .jsonc; Zed reads the deployed .json which is
# JSONC-tolerant). The live config is chezmoi-owned
# (dot_config/zed in the dotfiles repo), so existing files are never
# overwritten; capture tweaks with `chezmoi re-add`.
# Copy, never symlink: in-app settings changes replace the file atomically,
# which severs symlinks (zed-industries/zed#4469).
# Extensions install declaratively on next launch via auto_install_extensions.
# Reference: https://zed.dev/docs/configuring-zed
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

ZED_CONFIG="${HOME}/.config/zed"
MANIFEST_DIR="${FORGE_PROVISION_ROOT}/manifests/zed"

if ! command -v zed >/dev/null 2>&1 && [[ ! -d "/Applications/Zed.app" ]]; then
    echo "fail:zed (Zed not installed; run scripts/install/brew-bundle.sh)"
    exit 1
fi

mkdir -p "${ZED_CONFIG}"

for name in settings keymap tasks; do
    manifest_file="${MANIFEST_DIR}/${name}.jsonc"
    deployed_file="${ZED_CONFIG}/${name}.json"

    if [[ ! -f "${manifest_file}" ]]; then
        echo "fail:zed (manifest missing at ${manifest_file})"
        exit 1
    fi

    if [[ -f "${deployed_file}" ]]; then
        echo "skip:zed (${name}.json exists; chezmoi owns the live config)"
        continue
    fi

    echo "seed:zed (${name}.json)"
    cp "${manifest_file}" "${deployed_file}"
done

SNIPPET_SRC="${MANIFEST_DIR}/snippets/markdown.json"
SNIPPET_DST="${ZED_CONFIG}/snippets/markdown.json"

if [[ -f "${SNIPPET_DST}" ]]; then
    echo "skip:zed (snippets/markdown.json exists; chezmoi owns the live config)"
elif [[ -f "${SNIPPET_SRC}" ]]; then
    mkdir -p "${ZED_CONFIG}/snippets"
    echo "seed:zed (snippets/markdown.json)"
    cp "${SNIPPET_SRC}" "${SNIPPET_DST}"
fi

echo "ok:zed"
echo "      extensions listed in auto_install_extensions install on next launch"
