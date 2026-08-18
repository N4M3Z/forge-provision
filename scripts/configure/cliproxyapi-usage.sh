#!/bin/bash
# Make the local CLIProxyAPI reproducible from ~/.env: every setting the verify
# scripts assert is enforced here, so a fresh machine converges instead of
# failing checks nothing can heal.
#
#   binding      host 127.0.0.1 (the formula default binds all interfaces)
#   management   remote-management.secret-key seeded from CLIPROXY_MGMT_KEY
#                (plaintext is bcrypt-hashed by the server on startup)
#   attribution  one client API key per harness, generated into ~/.env and
#                registered under api-keys — the usage queue records carry the
#                key, so CPA-Manager-Plus splits spend by harness
#   logging      rotating file logs on, logs directory capped at 512MB
#   metering     usage statistics on, in-memory queue retention at its 3600s max
#   failover     fill-first routing and persisted cooldown state, so multiple
#                same-provider subscriptions drain in priority order: the
#                preferred account serves until quota-exhausted, the same
#                request continues on the next, and traffic returns when the
#                cooldown expires. force-model-prefix stays off so a prefixed
#                account still registers bare model ids and can take over;
#                "alt/<model>" keeps targeting it explicitly. Determinism
#                comes from "priority" in the auth JSON — the highest
#                available priority group wins exclusively, so exactly one
#                account per provider belongs at the top.
#   models       the `sol` Codex alias and the Proton Lumo provider (its key
#                lives in ~/.env as LUMO_API_KEY, never in this repo)
#
# Keys with consumers today: CLIPROXY_API_KEY (Claude Code + grok via
# ~/.config/zsh/cliproxy.zsh), CLIPROXY_API_KEY_CODEX (env_key in
# ~/.codex/config.toml). CLIPROXY_API_KEY_GEMINI is spare — agy accepts an
# endpoint override via the undocumented CLOUD_CODE_URL, but it speaks Cloud
# Code's /v1internal:* protocol, which this proxy answers only as an upstream
# target and 404s inbound, so agy stays on Google directly.
#
# Idempotent: keys are generated once, config edits only apply when missing.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CONF="$(brew --prefix)/etc/cliproxyapi.conf"

if [[ ! -f "${CONF}" ]]; then
    echo "fail:cliproxyapi-usage (no ${CONF}; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ -n "${DRY_RUN:-}" ]]; then
    echo "  would ensure: loopback bind, management key, per-harness keys,"
    echo "  file logging + 512MB log cap, usage stats + 3600s retention,"
    echo "  force-model-prefix, fill-first routing, session affinity,"
    echo "  persisted cooldowns, sol alias, Lumo"
    echo "skip:cliproxyapi-usage (dry-run)"
    exit 0
fi

changed=0

env_value() {
    grep "^${1}=" "$HOME/.env" 2>/dev/null | cut -d= -f2-
}

# The formula default binds all interfaces; only loopback is acceptable for a
# process holding subscription credentials.
if grep -q '^host: ""' "${CONF}"; then
    echo "configure:cliproxyapi (bind 127.0.0.1)"
    sed -i '' 's|^host: ""|host: "127.0.0.1"|' "${CONF}"
    changed=1
fi

# Management API key. Plaintext written here is hashed on startup, so the conf
# never keeps it readable; the plaintext of record stays in ~/.env.
if ! grep -q "^CLIPROXY_MGMT_KEY=" "$HOME/.env" 2>/dev/null; then
    echo "generate:CLIPROXY_MGMT_KEY"
    printf 'CLIPROXY_MGMT_KEY=%s\n' "$(openssl rand -hex 24)" >> "$HOME/.env"
fi
if grep -q '^  secret-key: ""' "${CONF}"; then
    echo "configure:cliproxyapi (seed management key)"
    sed -i '' "s|^  secret-key: \"\"|  secret-key: \"$(env_value CLIPROXY_MGMT_KEY)\"|" "${CONF}"
    changed=1
fi

for name in CLIPROXY_API_KEY CLIPROXY_API_KEY_CODEX CLIPROXY_API_KEY_GEMINI; do
    if ! grep -q "^${name}=" "$HOME/.env" 2>/dev/null; then
        echo "generate:${name}"
        printf '%s=%s\n' "${name}" "$(openssl rand -hex 24)" >> "$HOME/.env"
    fi
    key="$(env_value "${name}")"
    if ! grep -q "\"${key}\"" "${CONF}"; then
        echo "configure:cliproxyapi (add ${name} to api-keys)"
        sed -i '' "/^api-keys:/a\\
  - \"${key}\"
" "${CONF}"
        changed=1
    fi
done

# Plugins load as native code inside the process holding every subscription
# credential, and the plugin store fetches them from remote registries. None
# are installed, so the loader is off.
if grep -q '^plugins:' "${CONF}" && ! grep -qE '^  enabled: false' "${CONF}"; then
    echo "configure:cliproxyapi (plugin loader off)"
    sed -i '' '/^plugins:/{n;s|^  enabled: true|  enabled: false|;}' "${CONF}"
    changed=1
fi

# Application logs go to rotating files under ~/.cli-proxy-api/logs with a
# total-size cap. A canceled streaming request dumps its full request body as a
# multi-MB error file, so an uncapped logs directory grows without bound.
if grep -q '^logging-to-file: false' "${CONF}"; then
    echo "configure:cliproxyapi (file logging on)"
    sed -i '' 's|^logging-to-file: false|logging-to-file: true|' "${CONF}"
    changed=1
fi
if grep -q '^logs-max-total-size-mb: 0$' "${CONF}"; then
    echo "configure:cliproxyapi (cap logs directory at 512MB)"
    sed -i '' 's|^logs-max-total-size-mb: 0$|logs-max-total-size-mb: 512|' "${CONF}"
    changed=1
fi

if grep -q '^usage-statistics-enabled: false' "${CONF}"; then
    echo "configure:cliproxyapi (usage statistics on)"
    sed -i '' 's|^usage-statistics-enabled: false|usage-statistics-enabled: true|' "${CONF}"
    changed=1
fi

if grep -q '^redis-usage-queue-retention-seconds: 60$' "${CONF}"; then
    echo "configure:cliproxyapi (usage queue retention 3600s)"
    sed -i '' 's|^redis-usage-queue-retention-seconds: 60$|redis-usage-queue-retention-seconds: 3600|' "${CONF}"
    changed=1
fi

if grep -q '^force-model-prefix: true' "${CONF}"; then
    echo "configure:cliproxyapi (force-model-prefix off; prefixed accounts join failover)"
    sed -i '' 's|^force-model-prefix: true|force-model-prefix: false|' "${CONF}"
    changed=1
fi

if grep -q '^  strategy: "round-robin"' "${CONF}"; then
    echo "configure:cliproxyapi (fill-first routing; subscriptions drain in order)"
    sed -i '' 's|^  strategy: "round-robin"|  strategy: "fill-first"|' "${CONF}"
    changed=1
fi

# Session affinity pins a conversation to the credential that served it (1h
# TTL, the default). A mid-session account switch invalidates Anthropic's
# per-account prompt cache and shows up as return-probe 429 churn; affinity
# keeps a spilled session where it landed. Failover on an unavailable
# credential stays automatic.
if grep -q '^  session-affinity: false' "${CONF}"; then
    echo "configure:cliproxyapi (session affinity; conversations keep their account)"
    sed -i '' 's|^  session-affinity: false|  session-affinity: true|' "${CONF}"
    changed=1
fi

if grep -q '^save-cooldown-status: false' "${CONF}"; then
    echo "configure:cliproxyapi (persist cooldown state across restarts)"
    sed -i '' 's|^save-cooldown-status: false|save-cooldown-status: true|' "${CONF}"
    changed=1
fi

# GPT 5.6 Sol exposed as `sol` (codex --profile sol, rune launch sol@codex).
if ! grep -q '^oauth-model-alias:' "${CONF}"; then
    echo "configure:cliproxyapi (sol model alias)"
    printf 'oauth-model-alias:\n  codex:\n    - name: gpt-5.6-sol\n      alias: sol\n      fork: true\n' >> "${CONF}"
    changed=1
fi

# Proton Lumo as an OpenAI-compatible provider. Capture-on-touch both ways:
# a key found only in the conf migrates into ~/.env; a fresh conf gets the
# block rebuilt from ~/.env.
if ! grep -q "^LUMO_API_KEY=" "$HOME/.env" 2>/dev/null; then
    lumo_key="$(grep -o 'pst_[a-zA-Z0-9]*' "${CONF}" | head -1)"
    if [[ -n "${lumo_key}" ]]; then
        echo "capture:LUMO_API_KEY (from live conf into ~/.env)"
        printf 'LUMO_API_KEY=%s\n' "${lumo_key}" >> "$HOME/.env"
    fi
fi
if ! grep -q '^openai-compatibility:' "${CONF}"; then
    lumo_key="$(env_value LUMO_API_KEY)"
    if [[ -n "${lumo_key}" ]]; then
        echo "configure:cliproxyapi (Proton Lumo provider)"
        printf 'openai-compatibility:\n  - name: Proton Lumo\n    base-url: https://lumo.proton.me/api/ai/v1\n    api-key-entries:\n      - api-key: %s\n    models:\n      - name: lumo-lite\n      - name: lumo-max\n' "${lumo_key}" >> "${CONF}"
        changed=1
    fi
fi

if [[ ${changed} -eq 1 ]]; then
    brew services restart cliproxyapi >/dev/null
fi

echo "ok:cliproxyapi-usage (conf converged; consumer: cpa-manager-plus on :18317)"
