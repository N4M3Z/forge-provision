#!/bin/bash
# Configure Neovim with the LazyVim distro and copy user plugin specs from manifests/.
# Idempotent: skips the clone if ~/.config/nvim already exists, skips plugin copy
# if the destination file already matches the manifest.
# Reference: https://www.lazyvim.org · https://github.com/MeanderingProgrammer/render-markdown.nvim
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

NVIM_CONFIG="${HOME}/.config/nvim"
MANIFEST_DIR="${FORGE_PROVISION_ROOT}/manifests/nvim"
PLUGIN_SRC="${MANIFEST_DIR}/lua/plugins/markdown.lua"
PLUGIN_DST="${NVIM_CONFIG}/lua/plugins/markdown.lua"

if ! command -v nvim >/dev/null 2>&1; then
    echo "fail:nvim (neovim not on PATH, run scripts/install/brew-bundle.sh)"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "fail:nvim (git not on PATH)"
    exit 1
fi

if [[ ! -f "${PLUGIN_SRC}" ]]; then
    echo "fail:nvim (plugin source missing at ${PLUGIN_SRC})"
    exit 1
fi

if [[ -d "${NVIM_CONFIG}" ]]; then
    echo "skip:nvim-lazyvim (${NVIM_CONFIG} already exists)"
else
    echo "clone:LazyVim starter"
    git clone https://github.com/LazyVim/starter "${NVIM_CONFIG}" --depth 1 || {
        echo "fail:nvim-lazyvim (git clone failed)"
        exit 1
    }
    rm -rf "${NVIM_CONFIG}/.git"
fi

mkdir -p "$( dirname "${PLUGIN_DST}" )"

if [[ -f "${PLUGIN_DST}" ]] && cmp -s "${PLUGIN_SRC}" "${PLUGIN_DST}"; then
    echo "skip:nvim-render-markdown (plugin spec already matches manifest)"
else
    echo "copy:render-markdown.nvim plugin spec"
    cp "${PLUGIN_SRC}" "${PLUGIN_DST}"
fi

echo "ok:nvim"
echo "      first launch will install plugins automatically; run \`:checkhealth\` after"
