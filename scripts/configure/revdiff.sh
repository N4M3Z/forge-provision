#!/bin/bash
# Wire revdiff's opencode integration: copies launcher scripts + slash command
# into ~/.config/opencode/, registers the plan-review plugin in opencode.json.
# Delegates to the upstream setup.sh at https://github.com/umputun/revdiff
# (plugins/opencode/setup.sh) so we stay aligned with whatever the maintainer
# ships next. Idempotent — skips if the launcher is already in place.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
INTEGRATION_MARKER="${OPENCODE_CONFIG_DIR}/plugins/launch-plan-review.sh"
REVDIFF_REPO="https://github.com/umputun/revdiff.git"

if ! command -v revdiff >/dev/null 2>&1; then
    echo "fail:revdiff (revdiff binary not found — run brew bundle install first)"
    exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
    echo "skip:revdiff (opencode not installed; nothing to wire)"
    exit 0
fi

if [[ -f "${INTEGRATION_MARKER}" ]]; then
    echo "skip:revdiff (opencode plan-review plugin already wired at ${INTEGRATION_MARKER})"
    exit 0
fi

CLONE_DIR="$(mktemp -d "/tmp/revdiff-opencode-XXXXXX")"
trap 'rm -rf "${CLONE_DIR}"' EXIT

echo "fetch:revdiff source (shallow clone to ${CLONE_DIR})"
git clone --depth 1 --quiet "${REVDIFF_REPO}" "${CLONE_DIR}" || {
    echo "fail:revdiff (clone of ${REVDIFF_REPO} failed)"
    exit 1
}

SETUP_SCRIPT="${CLONE_DIR}/plugins/opencode/setup.sh"
if [[ ! -f "${SETUP_SCRIPT}" ]]; then
    echo "fail:revdiff (upstream layout changed — plugins/opencode/setup.sh not at expected path)"
    exit 1
fi

echo "run:plugins/opencode/setup.sh (writes into ${OPENCODE_CONFIG_DIR})"
bash "${SETUP_SCRIPT}" || {
    echo "fail:revdiff (upstream setup.sh exited non-zero)"
    exit 1
}

if [[ -f "${INTEGRATION_MARKER}" ]]; then
    echo "ok:revdiff (opencode plan-review plugin wired)"
    echo "      launcher: ${INTEGRATION_MARKER}"
    echo "      Claude Code: run \`/plugin install revdiff@revdiff\` inside Claude Code to wire that side"
else
    echo "fail:revdiff (setup.sh completed but ${INTEGRATION_MARKER} not present)"
    exit 1
fi
