#!/bin/bash
# Converge CPA-Manager-Plus, the persistence and dashboard layer for
# CLIProxyAPI's in-memory usage queue: drains per-request token records into
# local SQLite (~/.cpa-manager-plus/data/) and serves dashboards on :18317.
#
# The binary installs via Homebrew from the personal tap
# (N4M3Z/tap/cpa-manager-plus, declared in manifests/Brewfile) and runs under
# `brew services`. The formula's bin wrapper enters ~/.cpa-manager-plus before
# exec, because the app resolves its data directory relative to the path it
# was invoked through. `brew upgrade` owns version updates.
#
# What this script converges, none of which a formula can carry:
#   binding      httpAddr 127.0.0.1:18317 in config.json (app default is 0.0.0.0)
#   admin key    panel credential seeded from CPAMP_ADMIN_KEY in ~/.env — the
#                app otherwise generates a random key only this machine knows
#   migration    retires the legacy hand-rolled install: the
#                local.cpa-manager-plus LaunchAgent, the launcher shims, and
#                the copied binary in ~/.cpa-manager-plus (now a symlink into
#                the Homebrew keg, refreshed by the bin wrapper)
#
# Panel login uses the admin key in the SQLite settings table, distinct from
# the CLIProxyAPI management key the panel later asks for to drain the queue.
#
# Reference: https://github.com/seakee/CPA-Manager-Plus
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CPAMP_HOME="${HOME}/.cpa-manager-plus"
CONFIG_SRC="${FORGE_PROVISION_ROOT}/manifests/cpa-manager-plus/config.json"
BREW_PREFIX="$(brew --prefix)"
KEG_BINARY="${BREW_PREFIX}/opt/cpa-manager-plus/libexec/cpa-manager-plus"
LEGACY_PLIST="${HOME}/Library/LaunchAgents/local.cpa-manager-plus.plist"

remove_file() {
    /usr/bin/trash "$1" 2>/dev/null || command rm -f "$1"
}

if [[ -n "${DRY_RUN:-}" ]]; then
    echo "  would ensure: brew keg present, legacy LaunchAgent retired,"
    echo "  loopback bind, admin key from ~/.env, brew services running"
    echo "skip:cpa-manager-plus (dry-run)"
    exit 0
fi

if [[ ! -x "${KEG_BINARY}" ]]; then
    echo "fail:cpa-manager-plus (not installed; run scripts/install/brew-bundle.sh)"
    exit 1
fi

# Legacy hand-rolled install: one service manager, and it is brew services.
if launchctl print "gui/$(id -u)/local.cpa-manager-plus" >/dev/null 2>&1; then
    echo "migrate:cpa-manager-plus (retire local.cpa-manager-plus LaunchAgent)"
    launchctl bootout "gui/$(id -u)/local.cpa-manager-plus" 2>/dev/null
fi
[[ -f "${LEGACY_PLIST}" ]] && remove_file "${LEGACY_PLIST}"
if [[ -f "${CPAMP_HOME}/cpa-manager-plus" && ! -L "${CPAMP_HOME}/cpa-manager-plus" ]]; then
    echo "migrate:cpa-manager-plus (copied binary becomes a keg symlink)"
    remove_file "${CPAMP_HOME}/cpa-manager-plus"
fi
mkdir -p "${CPAMP_HOME}"
ln -sfn "${KEG_BINARY}" "${CPAMP_HOME}/cpa-manager-plus"
for legacy in "${CPAMP_HOME}/cpamp" "${CPAMP_HOME}/.version" \
    "${HOME}/.local/bin/cpa-manager-plus"; do
    [[ -e "${legacy}" || -L "${legacy}" ]] && remove_file "${legacy}"
done

# Loopback bind. The app writes 0.0.0.0 as its default and owns the file
# afterwards, so converge on the value rather than byte-comparing — a byte
# copy would fight the app's own rewrites forever.
restart_needed=0
if ! grep -q '"httpAddr": "127.0.0.1:18317"' "${CPAMP_HOME}/config.json" 2>/dev/null; then
    echo "config:cpa-manager-plus (bind 127.0.0.1:18317)"
    command cp "${CONFIG_SRC}" "${CPAMP_HOME}/config.json"
    restart_needed=1
fi

# Pin the panel credential to ~/.env so it is reproducible instead of a random
# value only this machine knows. Seeding needs the subcommand with the service
# down; a running server holds the database.
CPAMP_ADMIN_KEY="$(grep "^CPAMP_ADMIN_KEY=" "$HOME/.env" 2>/dev/null | cut -d= -f2)"
if [[ -z "${CPAMP_ADMIN_KEY}" ]]; then
    echo "generate:cpamp-admin-key"
    CPAMP_ADMIN_KEY="$(openssl rand -hex 24)"
    printf 'CPAMP_ADMIN_KEY=%s\n' "${CPAMP_ADMIN_KEY}" >> "$HOME/.env"
fi
if [[ ! -f "${CPAMP_HOME}/data/usage.sqlite" ]] ||
    ! sqlite3 "${CPAMP_HOME}/data/usage.sqlite" \
        "select 1 from settings where key='admin_credential_v1';" 2>/dev/null | grep -q 1; then
    echo "config:cpamp-admin-key (seeding panel credential from ~/.env)"
    brew services stop cpa-manager-plus >/dev/null 2>&1
    ( cd "${CPAMP_HOME}" && ./cpa-manager-plus reset-admin-key --admin-key "${CPAMP_ADMIN_KEY}" >/dev/null 2>&1 )
    restart_needed=1
fi

if ! brew services list | grep -q '^cpa-manager-plus[[:space:]]*started'; then
    echo "service:cpa-manager-plus (brew services start)"
    brew services start cpa-manager-plus >/dev/null
elif [[ ${restart_needed} -eq 1 ]]; then
    brew services restart cpa-manager-plus >/dev/null
fi

for _ in $(seq 1 10); do
    if curl -fsS -o /dev/null http://127.0.0.1:18317/ 2>/dev/null; then
        echo "ok:cpa-manager-plus (dashboard on https://usage.internal)"
        echo "      log in with CPAMP_ADMIN_KEY from ~/.env"
        echo "      then connect it to CLIProxyAPI: http://127.0.0.1:8317"
        echo "      with CLIPROXY_MGMT_KEY from ~/.env (a different key)"
        exit 0
    fi
    sleep 1
done
echo "warn:cpa-manager-plus (installed but :18317 not answering yet)"
