#!/bin/bash
# Install sd, the script-directory dispatcher (personal fork with multicall
# symlink dispatch). Idempotent: clones the fork once, refreshes symlinks on
# every run.
#
# sd runs executables from a topic tree (~/sd/<topic>/<verb>) as
# `sd <topic> <verb>`, with help text read from script comments. The fork
# adds busybox-style argv[0] dispatch so a symlink like tmux-battery -> sd
# resolves to ~/sd/tmux/battery — the escape hatch for callers that require
# bare single-word commands. The script tree itself is per-user runtime
# content and deploys from the dotfiles repo (dot_sd), not from here.
# Decision: docs/decisions/PROV-0024.
#
# Reference: https://github.com/N4M3Z/sd (fork of ianthehenry/sd)
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

SD_REPO="${HOME}/Developer/N4M3Z/sd"
SD_BIN="${HOME}/.local/bin/sd"
SD_COMPLETION="${HOME}/.config/zsh/functions/_sd"

if [[ -d "${SD_REPO}" ]]; then
    echo "skip:sd (repo present at ${SD_REPO})"
else
    echo "clone:sd"
    git clone https://github.com/N4M3Z/sd "${SD_REPO}"
fi

mkdir -p "$(dirname "${SD_BIN}")" "$(dirname "${SD_COMPLETION}")"
ln -sf "${SD_REPO}/sd" "${SD_BIN}"
ln -sf "${SD_REPO}/_sd" "${SD_COMPLETION}"

if command -v sd >/dev/null 2>&1; then
    echo "ok:sd (symlinked from the fork; completions in ~/.config/zsh/functions)"
else
    echo "warn:sd (installed but not on PATH; expected ~/.local/bin in PATH)"
fi
