#!/bin/bash
# Verify the coding harnesses actually route through the local CLIProxyAPI, so
# CPA-Manager-Plus meters their spend. Read-only.
#
# Each harness is wired by a different mechanism, and each has failed silently
# before, which is why this asserts them separately:
#   claude  ANTHROPIC_BASE_URL from ~/.config/zsh/cliproxy.zsh
#   grok    `sd agent run grok` exports GROK_MODELS_BASE_URL and a Grok-scoped
#           bearer into its child only; probed here with a fake binary
#   codex   model_provider in ~/.codex/config.toml — no environment override
#           exists, and a provider set only inside a profile does NOT apply to
#           `rune run codex` (HarnessCouncil's path), which rejects a profile's
#           --profile argument and falls back to the vendor endpoint unmetered.
#
# Account routing is checked too: with force-model-prefix on, an unprefixed
# model must resolve to exactly one credential. Left off, unprefixed requests
# load-balance across both Claude accounts mid-session, blending rate limits
# and corrupting per-account spend.
#
# `cliproxy off` is a deliberate state, not a failure — this skips when it is set.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

PROXY="http://127.0.0.1:8317"
CODEX_CONFIG="${HOME}/.codex/config.toml"
SHELL_WIRING="${HOME}/.config/zsh/cliproxy.zsh"
PROXY_CONF="$(brew --prefix)/etc/cliproxyapi.conf"

if [[ -e "${HOME}/.config/zsh/cliproxy.off" ]]; then
    echo "skip:harness-proxy (cliproxy off — deliberate; run \`cliproxy on\` to rewire)"
    exit 0
fi

if [[ ! -f "${SHELL_WIRING}" ]]; then
    echo "fail:harness-proxy (${SHELL_WIRING} missing — chezmoi apply)"
    exit 1
fi

failures=0
CLIPROXY_API_KEY="$(grep "^CLIPROXY_API_KEY=" "$HOME/.env" 2>/dev/null | cut -d= -f2-)"

if ! curl -fsS -o /dev/null --max-time 5 \
    -H "Authorization: Bearer ${CLIPROXY_API_KEY}" "${PROXY}/v1/models" 2>/dev/null; then
    echo "fail:harness-proxy (proxy not answering on ${PROXY})"
    exit 1
fi
echo "check:harness-proxy (proxy answering)"

# Codex: the assignment must be top level and uncommented. A commented marker
# means `cliproxy off` left it disabled without the flag file.
if grep -q '^model_provider = "cliproxyapi"' "${CODEX_CONFIG}" 2>/dev/null; then
    echo "check:harness-proxy (codex → proxy via config.toml)"
else
    echo "fail:harness-proxy (codex not routed; \`rune run codex\` would bypass the proxy unmetered)"
    ((failures++))
fi

# Per-harness attribution: each harness needs its own client key or the usage
# queue cannot split spend by harness.
if grep -q '^env_key = "CLIPROXY_API_KEY_CODEX"' "${CODEX_CONFIG}" 2>/dev/null; then
    echo "check:harness-proxy (codex uses its own attribution key)"
else
    echo "warn:harness-proxy (codex shares the default key; spend will not split by harness)"
fi

# Claude wiring, checked by sourcing the shell file the way a login shell
# would rather than trusting the file's contents.
shell_anthropic=""
eval "$(zsh -c "source '${SHELL_WIRING}' >/dev/null 2>&1;
    printf 'shell_anthropic=%s\n' \"\${ANTHROPIC_BASE_URL}\"" 2>/dev/null)"

if [[ "${shell_anthropic}" == "${PROXY}" ]]; then
    echo "check:harness-proxy (claude → proxy via shell env)"
else
    echo "fail:harness-proxy (claude not routed; got '${shell_anthropic:-unset}')"
    ((failures++))
fi

# Grok wiring lives in the launcher, not the shell: probe `sd agent run grok`
# with a fake binary that reports the endpoint and whether the injected bearer
# matches the client key, without ever printing key material.
SD_RUNNER="${HOME}/sd/agent/run"
if [[ -x "${SD_RUNNER}" ]]; then
    probe_dir="$(mktemp -d)"
    # shellcheck disable=SC2016 # the probe script expands these in the child, not here
    printf '%s\n' '#!/bin/bash' \
        'match=no' \
        '[[ -n "${GROK_CODE_XAI_API_KEY:-}" && "${GROK_CODE_XAI_API_KEY}" == "${PROBE_EXPECTED_KEY:-}" ]] && match=yes' \
        'printf "base=%s match=%s\n" "${GROK_MODELS_BASE_URL:-unset}" "${match}"' \
        > "${probe_dir}/grok"
    printf '%s\n' '#!/bin/bash' 'exit 0' > "${probe_dir}/session-sync"
    chmod +x "${probe_dir}/grok" "${probe_dir}/session-sync"
    probe_output="$(PROBE_EXPECTED_KEY="${CLIPROXY_API_KEY}" \
        HARNESS_REAL_BIN_DIR="${probe_dir}" SESSION_SYNC="${probe_dir}/session-sync" \
        "${SD_RUNNER}" grok 2>/dev/null)"
    rm -rf "${probe_dir}"
    if [[ "${probe_output}" == *"base=${PROXY}/v1"* && "${probe_output}" == *"match=yes"* ]]; then
        echo "check:harness-proxy (grok → proxy via sd agent run)"
    else
        echo "fail:harness-proxy (grok not routed through sd agent run; probe said '${probe_output:-nothing}')"
        ((failures++))
    fi
else
    echo "fail:harness-proxy (${SD_RUNNER} missing — chezmoi apply)"
    ((failures++))
fi

# Subscription failover: fill-first serves the highest-priority available
# credential, so a quota-exhausted account spills to the next one instead of
# load-balancing, and traffic returns once its cooldown expires.
if grep -q '^  strategy: "fill-first"' "${PROXY_CONF}" 2>/dev/null; then
    echo "check:harness-proxy (fill-first routing; subscriptions drain in order)"
else
    echo "fail:harness-proxy (routing.strategy not fill-first — subscriptions load-balance instead of draining in order)"
    ((failures++))
fi

# Affinity keeps a conversation on the credential that served it, so a
# spilled session is not dragged back mid-conversation when the preferred
# account's cooldown expires, which would invalidate its prompt cache.
if grep -q '^  session-affinity: true' "${PROXY_CONF}" 2>/dev/null; then
    echo "check:harness-proxy (session affinity; conversations keep their account)"
else
    echo "fail:harness-proxy (session-affinity off — mid-session account switches invalidate prompt caches)"
    ((failures++))
fi

# A prefixed credential registers bare model ids only while force-model-prefix
# is off. Turning it on removes every prefixed account from the bare pool,
# which silently takes it out of failover.
if grep -q '^force-model-prefix: false' "${PROXY_CONF}" 2>/dev/null; then
    echo "check:harness-proxy (prefixed accounts participate in failover)"
else
    echo "fail:harness-proxy (force-model-prefix on — prefixed accounts cannot take over when the primary is exhausted)"
    ((failures++))
fi

# Determinism now comes from priority, not from prefix exclusion: the highest
# priority group wins exclusively, so more than one account at the top would
# round-robin within it and blend accounts mid-session.
top_claude="$(for cred in "${HOME}"/.cli-proxy-api/claude-*.json; do
    [[ -f "${cred}" ]] && jq -r '.priority // 0' "${cred}" 2>/dev/null
done | sort -rn | awk 'NR==1{top=$1} $1==top' | wc -l | tr -d ' ')"
if [[ "${top_claude}" == "1" ]]; then
    echo "check:harness-proxy (one Claude account at top priority; the rest are spillover)"
else
    echo "fail:harness-proxy (${top_claude} Claude accounts share top priority; they would blend mid-session)"
    ((failures++))
fi

if [[ ${failures} -eq 0 ]]; then
    echo "ok:harness-proxy (claude, codex, grok routed and metered)"
else
    echo "fail:harness-proxy (${failures} checks failed)"
    exit 1
fi
