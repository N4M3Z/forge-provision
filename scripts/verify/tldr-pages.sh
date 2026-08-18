#!/bin/bash
# Verify tealdeer uses forge-provision's strict pages. This check does not update
# the network cache. A patch-page check therefore requires an existing cache.
# Source: https://github.com/N4M3Z/forge-provision

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

PAGES_DIR="${FORGE_PROVISION_ROOT}/docs/tldr-pages"
failures=0

fail() {
    echo "fail:tldr-pages ($1)"
    failures=$(( failures + 1 ))
}

if ! command -v tldr >/dev/null 2>&1; then
    echo "fail:tldr-pages (tldr not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

version="$(tldr --version 2>&1 || true)"
if [[ "${version}" != *tealdeer* ]]; then
    fail "active client is not tealdeer: ${version}"
fi

"${FORGE_PROVISION_ROOT}/scripts/validate/tldr-pages.sh" || failures=$(( failures + 1 ))

paths="$(NO_COLOR=1 tldr --show-paths 2>&1 || true)"
if [[ "${paths}" != *"${PAGES_DIR}"* ]]; then
    fail "custom page directory is not active"
fi

zed_page="$(NO_COLOR=1 tldr zed 2>&1 || true)"
if [[ "${zed_page}" != *"sd zed rebuild"* ]]; then
    fail "full local zed page did not resolve"
fi

tmux_page="$(NO_COLOR=1 tldr tmux 2>&1 || true)"
if [[ "${tmux_page}" != *"sd tmux session-name"* ]]; then
    fail "tmux patch did not resolve; update the upstream cache if it is absent"
fi

page_list="$(NO_COLOR=1 tldr --list 2>&1 || true)"
if [[ "${page_list}" != *zed* || "${page_list}" != *tmux* ]]; then
    fail "normal page listing does not contain zed and tmux"
fi

search_results="$(NO_COLOR=1 tldr --list | command grep -E '^(zed|tmux)$' || true)"
if [[ "${search_results}" != *zed* || "${search_results}" != *tmux* ]]; then
    fail "page list cannot find zed and tmux"
fi

if [[ "${failures}" -gt 0 ]]; then
    echo "fail:tldr-pages (${failures} checks failed)"
    exit 1
fi

echo "ok:tldr-pages (tealdeer full page, patch page, paths, and listing work)"
