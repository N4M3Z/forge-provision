#!/bin/bash
# Converge the Cloudflare development setup: verify the wrangler CLI, report
# auth state, and install Cloudflare's agent skills into ~/.claude/skills/.
# Auth itself is interactive (`wrangler login`) or token-based
# (CLOUDFLARE_API_TOKEN), never performed by this script. MCP servers are
# deliberately not configured.
# Reference: https://developers.cloudflare.com/agent-setup/
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v wrangler >/dev/null 2>&1; then
    echo "fail:cloudflare (wrangler not on PATH; install via brew bundle — Brewfile has cloudflare-wrangler)"
    exit 1
fi

echo "ok:wrangler ($(wrangler --version 2>/dev/null | command tail -1))"

if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    echo "ok:cloudflare-auth (CLOUDFLARE_API_TOKEN set in environment)"
else
    # `wrangler whoami` exits 0 either way; the unauthenticated case is only
    # detectable from its "You are not authenticated" message.
    whoami_output="$(wrangler whoami 2>/dev/null)"
    if [[ "${whoami_output}" == *"not authenticated"* || -z "${whoami_output}" ]]; then
        echo "warn:cloudflare-auth (not logged in)"
        echo "      interactive: wrangler login   (browser OAuth)"
        echo "      headless:    export CLOUDFLARE_API_TOKEN=\$(pass cloudflare/api-token)"
    else
        echo "ok:cloudflare-auth (OAuth session active)"
    fi
fi

# Cloudflare agent skills (https://developers.cloudflare.com/agent-setup/):
# retrieval-first skills for Workers, wrangler, Durable Objects, and the rest
# of the platform, installed globally for detected coding agents.
if [[ -d "${HOME}/.claude/skills/cloudflare" ]]; then
    echo "skip:cloudflare-skills (already in ~/.claude/skills/)"
elif ! command -v npx >/dev/null 2>&1; then
    echo "warn:cloudflare-skills (npx not on PATH; Brewfile installs node)"
elif [[ -n "${DRY_RUN:-}" ]]; then
    echo "  would run: npx -y skills add cloudflare/skills --skill '*' --yes --global"
    echo "skip:cloudflare-skills (dry-run)"
else
    echo "install:cloudflare-skills"
    npx -y skills add cloudflare/skills --skill '*' --yes --global || {
        echo "warn:cloudflare-skills (skills install failed; rerun manually)"
    }
fi
