#!/usr/bin/env bash
# Verify the AI-harness observability stack is not just running but actually ingesting.
#
# Every check here exists because a plausible-looking failure passed a weaker one:
# Alloy starts healthy against an empty config directory and listens on nothing, and
# Prometheus answers /-/healthy long before any harness metric reaches it.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

failures=0

check_http() {
    local label="$1" url="$2"
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null)"
    if [[ "${code}" == "200" ]]; then
        echo "ok:observability (${label} responds)"
    else
        echo "fail:observability (${label} returned ${code:-no response})"
        failures=$(( failures + 1 ))
    fi
}

check_http "prometheus" "http://127.0.0.1:9090/-/healthy"
check_http "victorialogs" "http://127.0.0.1:9428/health"
check_http "grafana" "http://127.0.0.1:3000/api/health"

# A listening socket, not a running process: Alloy with a misplaced config loads only
# its built-in nodes and binds nothing, while the service still reports as started.
if lsof -nP -iTCP:4318 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "ok:observability (alloy listening on 4318)"
else
    echo "fail:observability (nothing listening on 4318; check the alloy config path)"
    failures=$(( failures + 1 ))
fi

harness_metrics="$(curl -s 'http://127.0.0.1:9090/api/v1/label/__name__/values' 2>/dev/null \
    | tr ',' '\n' | grep -c 'claude_code_' || true)"
if [[ "${harness_metrics}" -gt 0 ]]; then
    echo "ok:observability (${harness_metrics} claude_code metrics in prometheus)"
else
    echo "fail:observability (no claude_code metrics; run a session and retry)"
    failures=$(( failures + 1 ))
fi

if [[ "${failures}" -eq 0 ]]; then
    echo "ok:observability (stack ingesting)"
else
    echo "fail:observability (${failures} checks failed)"
    exit 1
fi
