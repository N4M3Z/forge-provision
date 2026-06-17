#!/bin/bash
# Seed markdown-oxide config from manifests/moxide/ on first provision:
# settings.toml deployed to ~/.config/moxide/ only when absent. The live config
# is chezmoi-owned (dot_config/moxide in the dotfiles repo), so an existing file
# is never overwritten; capture tweaks with `chezmoi re-add`.
# The oxide LSP binary ships with the Zed "Markdown Oxide" extension (installed
# declaratively via auto_install_extensions); this only places its config.
# Reference: https://oxide.md
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

MOXIDE_CONFIG="${HOME}/.config/moxide"
MANIFEST_FILE="${FORGE_PROVISION_ROOT}/manifests/moxide/settings.toml"
DEPLOYED_FILE="${MOXIDE_CONFIG}/settings.toml"

if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "fail:markdown-oxide (manifest missing at ${MANIFEST_FILE})"
    exit 1
fi

mkdir -p "${MOXIDE_CONFIG}"

if [[ -f "${DEPLOYED_FILE}" ]]; then
    echo "skip:markdown-oxide (settings.toml exists; chezmoi owns the live config)"
    echo "ok:markdown-oxide"
    exit 0
fi

echo "seed:markdown-oxide (settings.toml)"
cp "${MANIFEST_FILE}" "${DEPLOYED_FILE}"
echo "ok:markdown-oxide"
