#!/usr/bin/env bash
# Wire the local AI-harness observability stack: Alloy on 4318, Prometheus for
# metrics, VictoriaLogs for logs, Grafana for dashboards. All Homebrew services,
# no containers.
#
# Every harness already exports OTLP to localhost:4318 (Claude Code via settings.json,
# Codex via [otel] in config.toml, Grok via [telemetry] in config.toml), so Alloy is
# what turns those exports from discarded into queryable. Retention is capped in both
# backends: Prometheus by size, VictoriaLogs by bytes on disk.
#
# Idempotent: re-copies only when content differs, restarts only what changed.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

BREW_PREFIX="$(brew --prefix)"
SRC="${FORGE_PROVISION_ROOT}/manifests/observability"
GRAFANA_PROVISION="${BREW_PREFIX}/etc/grafana/provisioning/datasources"
# The launch agent runs `alloy run <dir>` against etc/grafana-alloy, not etc/alloy.
# Alloy starts and reports healthy with an empty config directory, loading only its
# built-in nodes, so a wrong path fails silently: the service looks up while nothing
# listens on 4318.
ALLOY_CONFIG_DIR="${BREW_PREFIX}/etc/grafana-alloy"

for formula in prometheus victorialogs grafana grafana-alloy; do
    if ! brew list --versions "${formula}" >/dev/null 2>&1; then
        echo "fail:observability (${formula} not installed — run brew bundle first)"
        exit 1
    fi
done

restart_needed=""

deploy() {
    local src="$1" dest="$2" label="$3" service="$4"
    mkdir -p "$( dirname "${dest}" )"
    if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
        echo "skip:observability (${label} already current)"
        return
    fi
    command cp "${src}" "${dest}"
    echo "ok:observability (${label} -> ${dest})"
    restart_needed="${restart_needed} ${service}"
}

# Grafana's provisioning dir defaults to conf/provisioning *relative to homepath*,
# which under Homebrew is a versioned Cellar path wiped on every upgrade. Point it at
# the stable etc tree instead, or provisioned datasources and dashboards silently
# never load: the API just returns an empty list with no error anywhere.
GRAFANA_INI="${BREW_PREFIX}/etc/grafana/grafana.ini"
if grep -qE "^provisioning = ${GRAFANA_PROVISION%/datasources}$" "${GRAFANA_INI}" 2>/dev/null; then
    echo "skip:observability (grafana provisioning path already set)"
else
    /usr/bin/sed -i '' \
        "s|^;provisioning = conf/provisioning$|provisioning = ${GRAFANA_PROVISION%/datasources}|" \
        "${GRAFANA_INI}"
    echo "ok:observability (grafana provisioning path -> ${GRAFANA_PROVISION%/datasources})"
    restart_needed="${restart_needed} grafana"
fi

deploy "${SRC}/config.alloy" "${ALLOY_CONFIG_DIR}/config.alloy" "alloy config" "grafana-alloy"
deploy "${SRC}/prometheus.args" "${BREW_PREFIX}/etc/prometheus.args" "prometheus args" "prometheus"
deploy "${SRC}/datasources.yaml" "${GRAFANA_PROVISION}/forge.yaml" "grafana datasources" "grafana"
deploy "${SRC}/dashboards.yaml" "${BREW_PREFIX}/etc/grafana/provisioning/dashboards/forge.yaml" \
    "grafana dashboard provider" "grafana"

# Dashboards are file-backed rather than hand-imported, so a fresh machine gets the
# same panels. Their datasource is bound to the fixed uid in datasources.yaml because
# a provisioned dashboard cannot prompt for the __inputs a grafana.com export carries.
DASHBOARD_DIR="${BREW_PREFIX}/etc/grafana/dashboards/forge"
mkdir -p "${DASHBOARD_DIR}"
for dashboard in "${SRC}"/dashboards/*.json; do
    [[ -e "${dashboard}" ]] || continue
    deploy "${dashboard}" "${DASHBOARD_DIR}/$( basename "${dashboard}" )" \
        "dashboard $( basename "${dashboard}" .json )" "grafana"
done

# VictoriaLogs runs under its own LaunchAgent, not brew services: the formula's
# plist hardcodes its flags, so an args file cannot carry the retention caps, and
# the byte cap is the guarantee that matters. retentionPeriod alone cannot bound
# a burst of verbose tool output.
VICTORIALOGS_PLIST="${HOME}/Library/LaunchAgents/forge.victorialogs.plist"
if brew services list | grep -qE '^victorialogs\s+started'; then
    brew services stop victorialogs >/dev/null
    echo "ok:observability (victorialogs brew service stopped; LaunchAgent owns it)"
fi
if [[ -f "${VICTORIALOGS_PLIST}" ]] && cmp -s "${SRC}/forge.victorialogs.plist" "${VICTORIALOGS_PLIST}"; then
    echo "skip:observability (victorialogs plist already current)"
else
    command cp "${SRC}/forge.victorialogs.plist" "${VICTORIALOGS_PLIST}"
    launchctl bootout "gui/$(id -u)/forge.victorialogs" 2>/dev/null
    launchctl bootstrap "gui/$(id -u)" "${VICTORIALOGS_PLIST}"
    echo "ok:observability (victorialogs LaunchAgent bootstrapped)"
fi

# Homebrew's grafana ships a single `grafana` binary; the standalone grafana-cli
# of older releases is gone, and the plugin manager lives under `grafana cli`.
# --homepath is required: without it the CLI exits with "Could not find config
# defaults" before doing anything, so a suppressed invocation looks successful
# while installing nothing.
PLUGINS_DIR="${BREW_PREFIX}/var/lib/grafana/plugins"
if [[ -d "${PLUGINS_DIR}/victoriametrics-logs-datasource" ]]; then
    echo "skip:observability (victorialogs datasource plugin present)"
else
    if grafana cli --homepath "${BREW_PREFIX}/opt/grafana/share/grafana" \
            --pluginsDir "${PLUGINS_DIR}" \
            plugins install victoriametrics-logs-datasource >/dev/null \
        && [[ -d "${PLUGINS_DIR}/victoriametrics-logs-datasource" ]]; then
        echo "ok:observability (victoriametrics-logs-datasource installed)"
        restart_needed="${restart_needed} grafana"
    else
        echo "fail:observability (victoriametrics-logs-datasource install failed)"
        exit 1
    fi
fi

for service in prometheus grafana grafana-alloy; do
    if brew services list | grep -qE "^${service}\s+started"; then
        case "${restart_needed}" in
            *"${service}"*)
                brew services restart "${service}" >/dev/null
                echo "ok:observability (${service} restarted)"
                ;;
            *) echo "skip:observability (${service} already running)" ;;
        esac
    else
        brew services start "${service}" >/dev/null
        echo "ok:observability (${service} started)"
    fi
done
