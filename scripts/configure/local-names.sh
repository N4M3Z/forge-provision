#!/bin/bash
# Give the local services named HTTPS URLs: https://grafana.internal instead of
# http://127.0.0.1:3000. Three layers, all on loopback:
#   dnsmasq  resolves *.internal to 127.0.0.1 (port 5354, no root needed)
#   mkcert   issues one wildcard certificate for *.internal
#   Caddy    terminates TLS on :443 and routes by Host header to each port
# Idempotent: certificates and the resolver file are created only when absent,
# manifests deploy only when their content differs, and service starts are
# safe to re-run.
#
# /etc/resolver/internal scopes macOS to send only this suffix to the local
# resolver, so system DNS stays untouched and ProtonVPN and Tailscale keep
# resolving everything else. Nothing is broadcast: unlike an mDNS name, a
# loopback answer never leaves the machine, so the names work offline and on
# untrusted networks alike.
#
# Two steps need a password and cannot be scripted around: writing
# /etc/resolver/ and starting Caddy (binding 443 requires root). Both detect a
# non-interactive sudo and fail with the exact command instead of hanging.
#
# The AI harnesses deliberately keep pointing at http://127.0.0.1:8317, so
# Claude Code and Codex never depend on this stack being healthy.
#
# Reference: https://caddyserver.com/docs/caddyfile · man 5 resolver
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

SUFFIX="internal"
BREW_PREFIX="$(brew --prefix)"
TLS_DIR="${BREW_PREFIX}/etc/caddy/tls"
CERT="${TLS_DIR}/${SUFFIX}.pem"
KEY="${TLS_DIR}/${SUFFIX}-key.pem"
RESOLVER="/etc/resolver/${SUFFIX}"
DNSMASQ_MANIFEST="${FORGE_PROVISION_ROOT}/manifests/dnsmasq/internal.conf"
DNSMASQ_DEPLOYED="${BREW_PREFIX}/etc/dnsmasq.d/internal.conf"
CADDY_MANIFEST="${FORGE_PROVISION_ROOT}/manifests/caddy/Caddyfile"
CADDY_DEPLOYED="${BREW_PREFIX}/etc/Caddyfile"

for tool in mkcert dnsmasq caddy; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "fail:local-names (${tool} not on PATH — run scripts/install/brew-bundle.sh)"
        exit 1
    fi
done

for manifest in "${DNSMASQ_MANIFEST}" "${CADDY_MANIFEST}"; do
    if [[ ! -f "${manifest}" ]]; then
        echo "fail:local-names (manifest missing at ${manifest})"
        exit 1
    fi
done

if [[ -n "${DRY_RUN:-}" ]]; then
    echo "  would ensure: ${CERT}, ${DNSMASQ_DEPLOYED}, ${CADDY_DEPLOYED}, ${RESOLVER}"
    echo "  would start:  dnsmasq (user), caddy (root)"
    echo "skip:local-names (dry-run)"
    exit 0
fi

# The mkcert root CA must be trusted before Caddy serves its certificate,
# or every client rejects the connection. `security find-certificate` exits 0
# even when it matches nothing, so test the output.
if [[ -z "$(security find-certificate -c mkcert -a /Library/Keychains/System.keychain 2>/dev/null)" ]]; then
    echo "fail:local-names (mkcert CA not in the system keychain)"
    echo "      run \`mkcert -install\` from an interactive terminal, then rerun this script"
    exit 1
fi

# The certificate carries every Caddy site name as an explicit SAN — a
# `*.internal` wildcard is rejected by validators as a public-suffix wildcard,
# the same rule that outlaws `*.com`. Names come from the Caddyfile site
# blocks, so the cert follows the routes; reissue whenever one is missing.
# Site-address lines start with a name and may list several, comma-separated
# (`brain.internal, memex.internal {`), so extract every name on those lines.
names=()
while IFS= read -r name; do
    names+=("${name}")
done < <(grep -E "^[a-z0-9-]+\.${SUFFIX}" "${CADDY_MANIFEST}" | grep -oE "[a-z0-9-]+\.${SUFFIX}")

if [[ ${#names[@]} -eq 0 ]]; then
    echo "fail:local-names (no *.${SUFFIX} site blocks found in ${CADDY_MANIFEST})"
    exit 1
fi

reissue=0
if [[ ! -f "${CERT}" || ! -f "${KEY}" ]]; then
    reissue=1
else
    san_list="$(openssl x509 -in "${CERT}" -noout -ext subjectAltName 2>/dev/null)"
    for name in "${names[@]}"; do
        if [[ "${san_list}" != *"DNS:${name}"* ]]; then
            reissue=1
            break
        fi
    done
fi

if [[ ${reissue} -eq 1 ]]; then
    echo "generate:certificate (${#names[@]} ${SUFFIX} names)"
    mkdir -p "${TLS_DIR}"
    mkcert -cert-file "${CERT}" -key-file "${KEY}" "${names[@]}" >/dev/null 2>&1
    if [[ ! -f "${CERT}" ]]; then
        echo "fail:local-names (mkcert did not produce ${CERT})"
        exit 1
    fi
    restart_caddy_for_cert=1
fi

restart_dnsmasq=0
restart_caddy=0

deploy() {
    local src="$1" dest="$2" label="$3"
    if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
        echo "skip:local-names (${label} already current)"
        return 1
    fi
    mkdir -p "$(dirname "${dest}")"
    command cp "${src}" "${dest}"
    echo "copy:local-names (${label} → ${dest})"
    return 0
}

deploy "${DNSMASQ_MANIFEST}" "${DNSMASQ_DEPLOYED}" "dnsmasq fragment" && restart_dnsmasq=1
deploy "${CADDY_MANIFEST}" "${CADDY_DEPLOYED}" "Caddyfile" && restart_caddy=1

if ! caddy validate --config "${CADDY_DEPLOYED}" >/dev/null 2>&1; then
    echo "fail:local-names (Caddyfile rejected by \`caddy validate\`)"
    caddy validate --config "${CADDY_DEPLOYED}" 2>&1 | sed 's/^/      /' | tail -5
    exit 1
fi

# Scope macOS to send only *.internal to the local resolver. The one root step.
if [[ ! -f "${RESOLVER}" ]]; then
    if ! sudo -n true 2>/dev/null; then
        echo "fail:local-names (${RESOLVER} needs sudo; run this line, then rerun)"
        echo "      sudo mkdir -p /etc/resolver && printf 'nameserver 127.0.0.1\\nport 5354\\n' | sudo tee ${RESOLVER}"
        exit 1
    fi
    echo "resolve:${SUFFIX} → 127.0.0.1:5354"
    sudo mkdir -p /etc/resolver
    printf 'nameserver 127.0.0.1\nport 5354\n' | sudo tee "${RESOLVER}" >/dev/null
fi

# dnsmasq binds 5354, so it runs unprivileged as a user LaunchAgent.
if [[ ${restart_dnsmasq} -eq 1 ]]; then
    echo "start:dnsmasq (restart, config changed)"
    brew services restart dnsmasq >/dev/null
else
    brew services start dnsmasq >/dev/null 2>&1
fi

# Caddy binds *:443 unprivileged (macOS allows users the wildcard bind on low
# ports, and tailscaled no longer claims 443 — gbrain's Funnel sits on :8443).
# The LAN-facing side of that wildcard is closed with a Little Snitch inbound
# deny rule for caddy, not with the bind address.
if [[ ${restart_caddy} -eq 1 || ${restart_caddy_for_cert:-0} -eq 1 ]]; then
    echo "start:caddy (restart, config or certificate changed)"
    brew services restart caddy >/dev/null
else
    brew services start caddy >/dev/null 2>&1
fi

for _ in $(seq 1 15); do
    if curl -fsS -o /dev/null "https://cliproxy.${SUFFIX}/v1/models" 2>/dev/null ||
        [[ "$(curl -s -o /dev/null -w '%{http_code}' "https://cliproxy.${SUFFIX}/" --max-time 2 2>/dev/null)" != "000" ]]; then
        echo "ok:local-names (https://<service>.${SUFFIX} answering with trusted TLS)"
        echo "      ${names[*]%.${SUFFIX}}"
        exit 0
    fi
    sleep 1
done
echo "warn:local-names (configured but https://cliproxy.${SUFFIX} not answering yet)"
