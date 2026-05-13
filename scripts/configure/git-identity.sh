#!/bin/bash
# Set ~/.gitconfig user.name + user.email from .env (GIT_NAME, GIT_EMAIL).
# Idempotent — git config writes are absolute, not appending.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
    echo "fail:git-identity (GIT_NAME and GIT_EMAIL must be set in .env)"
    exit 1
fi

CURRENT_NAME="$(git config --global user.name 2>/dev/null || true)"
CURRENT_EMAIL="$(git config --global user.email 2>/dev/null || true)"

if [[ "${CURRENT_NAME}" == "${GIT_NAME}" && "${CURRENT_EMAIL}" == "${GIT_EMAIL}" ]]; then
    echo "skip:git-identity (already ${GIT_NAME} <${GIT_EMAIL}>)"
    exit 0
fi

echo "set:user.name=${GIT_NAME}"
git config --global user.name "${GIT_NAME}"

echo "set:user.email=${GIT_EMAIL}"
git config --global user.email "${GIT_EMAIL}"

echo "ok:git-identity"
echo "      verify: git config --global user.name && git config --global user.email"
