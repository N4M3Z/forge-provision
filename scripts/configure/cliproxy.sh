#!/bin/bash
# Configure CLIProxyAPI as a localhost-only API front for the CLI provider
# subscriptions, so each harness points at one base URL instead of carrying its
# own provider auth.
#
# The config path is compiled into the binary at build time
# (/opt/homebrew/etc/cliproxyapi.conf, a copy of the project's
# config.example.yaml), so this script edits that file in place with yq rather
# than writing a new one, preserving the upstream comments.
#
# Not done here, because both need a human: the provider OAuth logins
# (`cliproxyapi -claude-login`, `-codex-login`, `-antigravity-login`,
# `-xai-login`, `-kimi-login`) and pointing the harnesses at the endpoint.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CONFIG="${CLIPROXY_CONFIG:-/opt/homebrew/etc/cliproxyapi.conf}"
PASS_ITEM="${CLIPROXY_PASS_ITEM:-CLIProxyAPI}"

if ! command -v cliproxyapi >/dev/null 2>&1; then
    echo "skip:cliproxy (cliproxyapi not installed; run scripts/install/brew-bundle.sh)"
    exit 0
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "fail:cliproxy (yq not on PATH; it edits the YAML config structurally)"
    exit 1
fi

if [[ ! -f "${CONFIG}" ]]; then
    echo "fail:cliproxy (config not found at ${CONFIG}; reinstall cliproxyapi)"
    exit 1
fi

# Every edit below rewrites the config in place. A sandboxed shell can be denied
# writes under the Homebrew prefix, and yq reports that per-call rather than
# up front, so establish writability once and say so plainly.
if [[ ! -w "${CONFIG}" ]]; then
    echo "fail:cliproxy (${CONFIG} is not writable from this shell)"
    exit 1
fi

# Fail loudly on a rejected write instead of reporting configuration that never
# landed. Callers pass the yq expression; the config path is implicit.
edit_config() {
    yq -i "$1" "${CONFIG}" || {
        echo "fail:cliproxy (writing ${CONFIG} failed: $1)"
        exit 1
    }
}

# Bind loopback only. The shipped default is an empty host, which binds every
# interface: the proxy holds provider credentials and answers to anything that
# presents an api-key, so it must not be reachable off this machine.
if [[ "$(yq -r '.host' "${CONFIG}")" != "127.0.0.1" ]]; then
    edit_config '.host = "127.0.0.1"'
    echo "config:cliproxy (host=127.0.0.1)"
else
    echo "skip:cliproxy (host already 127.0.0.1)"
fi

# allow-remote stays false and the management secret stays empty, which the
# upstream config documents as disabling the management API and its control
# panel outright. Nothing here needs them, and both widen the surface.
edit_config '.remote-management.allow-remote = false'

# The shipped config carries three "your-api-key-N" placeholders. Anything that
# still matches that shape is not a usable key.
current_key="$(yq -r '.api-keys[0] // ""' "${CONFIG}")"

if [[ -n "${current_key}" && "${current_key}" != your-api-key-* ]]; then
    echo "skip:cliproxy (api key already set)"
else
    api_key=""

    # Proton Pass first, so a rebuilt machine reuses the key its harnesses are
    # already configured with. Reading it needs an authenticated session, and an
    # unauthenticated vault can block on a login or Keychain prompt instead of
    # returning, so the read runs under a watchdog and a logged-out vault falls
    # through to generation rather than stalling provisioning.
    pass_json=""
    if command -v pass-cli >/dev/null 2>&1; then
        pass_output="$(mktemp "${TMPDIR:-/tmp}/cliproxy-pass.XXXXXX")" || exit 1
        pass-cli item list --output json --show-secrets > "${pass_output}" 2>/dev/null &
        pass_pid=$!
        ( sleep "${CLIPROXY_PASS_TIMEOUT:-10}"; kill -TERM "${pass_pid}" 2>/dev/null ) &
        watchdog_pid=$!
        wait "${pass_pid}" 2>/dev/null
        pass_status=$?
        kill -TERM "${watchdog_pid}" 2>/dev/null

        if [[ ${pass_status} -eq 0 ]]; then
            pass_json="$(cat "${pass_output}")"
        else
            echo "skip:cliproxy (Proton Pass unreadable or timed out; generating a key instead)"
        fi
        command rm -f "${pass_output}"
    fi

    if [[ -n "${pass_json}" ]]; then
        api_key="$(jq -r --arg item "${PASS_ITEM}" '
            [ .. | objects | select((.title? // .name?) == $item) ]
            | first // {}
            | (.password? // .content?.password? // "")
        ' <<< "${pass_json}" 2>/dev/null)"
        [[ -n "${api_key}" && "${api_key}" != "null" ]] \
            && echo "read:cliproxy (api key from Proton Pass item '${PASS_ITEM}')" \
            || api_key=""
    fi

    if [[ -z "${api_key}" ]]; then
        api_key="$(openssl rand -hex 32)" || {
            echo "fail:cliproxy (could not generate an api key)"
            exit 1
        }
        echo "generate:cliproxy (api key generated locally)"
        echo "      store it in Proton Pass as item '${PASS_ITEM}' to reuse it on the next machine"
    fi

    # Replace the placeholder list wholesale: one key, not three.
    CLIPROXY_KEY="${api_key}" edit_config '.api-keys = [env(CLIPROXY_KEY)]'
    echo "config:cliproxy (api-keys set)"
fi

port="$(yq -r '.port' "${CONFIG}")"

if [[ -n "${TMUX:-}" ]]; then
    # Homebrew refuses `brew services` under tmux, because launchctl would
    # target tmux's bootstrap namespace rather than the login session.
    echo "manual:cliproxy (brew services cannot run under tmux)"
    echo "      start it from a shell outside tmux: brew services start cliproxyapi"
elif brew services list 2>/dev/null | grep -qE '^cliproxyapi\s+started'; then
    echo "skip:cliproxy-service (already started)"
else
    echo "start:cliproxy-service (launchd, keep-alive)"
    brew services start cliproxyapi >/dev/null || {
        echo "fail:cliproxy (brew services start failed)"
        exit 1
    }
fi

# The service takes a moment to bind after launchd starts it.
for _ in $(seq 1 10); do
    if nc -z 127.0.0.1 "${port}" 2>/dev/null; then
        echo "ok:cliproxy (listening on 127.0.0.1:${port})"
        echo "      log in per provider: cliproxyapi -claude-login | -codex-login | -antigravity-login | -xai-login"
        echo "      read the key back with: yq -r '.api-keys[0]' ${CONFIG}"
        exit 0
    fi
    sleep 1
done

echo "warn:cliproxy (service started but nothing is listening on 127.0.0.1:${port} yet)"
