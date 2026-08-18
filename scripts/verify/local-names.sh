#!/bin/bash
# Verify the *.internal naming stack: each name resolves to loopback, answers
# over HTTPS with a certificate the system already trusts, and is NOT reachable
# from the network. Read-only.
#
# A 502 counts as a pass: the name resolved, TLS terminated, and Caddy answered —
# the backend simply is not running. Only a resolution failure, a TLS failure, or
# a connection that never completes is a real fault. curl runs without --cacert
# on purpose, so an untrusted mkcert CA shows up here as a failure.
#
# The last check is the important one. Caddy binds *:443 (macOS offers an
# unprivileged process no other option on a low port), so the listener faces
# every interface, and only a Little Snitch inbound deny keeps it shut. That is
# policy living outside this repo, so it is verified rather than assumed: the
# probe connects to this machine's own non-loopback addresses carrying a
# spoofed Host header — byte for byte the request a neighbour on the same
# network would send.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

SUFFIX="internal"
NAMES=(cliproxy cpamc usage cpamp grafana prometheus victorialogs alloy ollama omlx lmstudio brain memex)

if [[ ! -f "/etc/resolver/${SUFFIX}" ]]; then
    echo "skip:local-names (no /etc/resolver/${SUFFIX}; run scripts/configure/local-names.sh)"
    exit 0
fi

failures=0

for name in "${NAMES[@]}"; do
    host="${name}.${SUFFIX}"

    if ! dscacheutil -q host -a name "${host}" 2>/dev/null | grep -q '127.0.0.1'; then
        echo "fail:local-names (${host} does not resolve to 127.0.0.1)"
        ((failures++))
        continue
    fi

    code="$(curl -s -o /dev/null -w '%{http_code}' "https://${host}/" --max-time 5 2>/dev/null)"
    if [[ "${code}" == "000" ]]; then
        echo "fail:local-names (${host} resolves but HTTPS did not complete — TLS or Caddy)"
        ((failures++))
        continue
    fi

    if [[ "${code}" == "502" || "${code}" == "503" ]]; then
        echo "warn:local-names (${host} ok, backend down — HTTP ${code})"
    else
        echo "check:local-names (${host} → HTTP ${code})"
    fi
done

# The listener must answer on loopback only. Probe every non-loopback address
# this machine holds — LAN, and tailnet if Tailscale is up — with a spoofed
# Host header. Anything other than a dead connection means the deny rule is
# missing or has stopped matching.
probe="${NAMES[0]}.${SUFFIX}"
addrs=()
while IFS= read -r addr; do
    addrs+=("${addr}")
done < <(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.')

if [[ ${#addrs[@]} -eq 0 ]]; then
    echo "skip:local-names (no non-loopback address; network exposure not testable)"
else
    for addr in "${addrs[@]}"; do
        # --resolve, not --connect-to: the latter reports an unreachable
        # connection for listeners that are in fact reachable, which would make
        # this check silently unfailable.
        code="$(curl -sk -o /dev/null -w '%{http_code}' \
            --resolve "${probe}:443:${addr}" \
            "https://${probe}/" --max-time 5 2>/dev/null)"
        if [[ "${code}" == "000" ]]; then
            echo "check:local-names (${addr}:443 refused — listener not exposed)"
        else
            echo "fail:local-names (${addr}:443 answered HTTP ${code} — listener EXPOSED)"
            echo "      add a Little Snitch rule denying any incoming connection for"
            echo "      /opt/homebrew/opt/caddy/bin/caddy (no outgoing rule needed)"
            ((failures++))
        fi

        # CPA-Manager-Plus holds the spend history; its raw port must be bound
        # to loopback (manifests/cpa-manager-plus/config.json), not merely
        # firewalled. usage.internal keeps working — Caddy proxies over loopback.
        code="$(curl -s -o /dev/null -w '%{http_code}' \
            "http://${addr}:18317/" --max-time 5 2>/dev/null)"
        if [[ "${code}" == "000" ]]; then
            echo "check:local-names (${addr}:18317 refused — cpa-manager-plus loopback-only)"
        else
            echo "fail:local-names (${addr}:18317 answered HTTP ${code} — spend DB EXPOSED)"
            echo "      set httpAddr to 127.0.0.1:18317 in ~/.cpa-manager-plus/config.json"
            echo "      (scripts/install/cpa-manager-plus.sh converges it) and restart"
            ((failures++))
        fi
    done
fi

if [[ ${failures} -eq 0 ]]; then
    echo "ok:local-names (names resolve, TLS trusted, listener loopback-only)"
else
    echo "fail:local-names (${failures} checks failed)"
    exit 1
fi
