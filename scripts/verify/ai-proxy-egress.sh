#!/bin/bash
# Verify the local AI proxy stack reaches only model vendors. Read-only.
#
# The proxy holds every subscription credential and sees every prompt, so this
# checks the two controls that keep it contained and then looks at what it is
# actually doing:
#
#   surface    the plugin loader off (plugins are in-process native code, and
#              the plugin store fetches them from remote registries), and
#              remote management refused from anything but loopback
#   egress     every established connection resolved and matched against the
#              vendor allowlist; anything else is reported with its address
#
# Firewall rules cannot be read back from Little Snitch here, so enforcement
# is verified by its effect: an unexpected remote means the rules are missing,
# were not imported, or stopped matching the process path.
#
# A vendor added later shows up as an unexpected remote until its domain is
# added both here and to manifests/littlesnitch/ai-proxy-containment.lsrules.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

CONF="$(brew --prefix)/etc/cliproxyapi.conf"
# Model vendors, plus the two code-delivery endpoints allowed by decision: the
# management panel assets on GitHub and the Antigravity auto-updater.
VENDOR_PATTERN='anthropic\.com|claude\.ai|openai\.com|chatgpt\.com|googleapis\.com|google\.com|x\.ai|grok\.com|proton\.me|github\.com|githubusercontent\.com|run\.app'

if [[ ! -f "${CONF}" ]]; then
    echo "skip:ai-proxy-egress (no ${CONF})"
    exit 0
fi

failures=0

if grep -qE '^  enabled: false' "${CONF}" && grep -q '^plugins:' "${CONF}"; then
    echo "check:ai-proxy-egress (plugin loader off)"
else
    echo "fail:ai-proxy-egress (plugin loader on — plugins run as native code inside the credential holder)"
    ((failures++))
fi

if grep -q '^  allow-remote: false' "${CONF}"; then
    echo "check:ai-proxy-egress (management refused off loopback)"
else
    echo "fail:ai-proxy-egress (remote management allowed)"
    ((failures++))
fi

# What the processes are actually talking to.
for service in "cliproxyapi:8317" "cpa-manager-plus:18317"; do
    name="${service%%:*}"
    port="${service#*:}"
    pid="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | head -1)"

    if [[ -z "${pid}" ]]; then
        echo "skip:ai-proxy-egress (${name} not running)"
        continue
    fi

    unexpected=0
    while IFS= read -r remote; do
        address="${remote%:*}"
        address="${address#[}"
        address="${address%]}"

        # Loopback is the whole point of this stack; it is never egress.
        if [[ "${address}" == "127.0.0.1" || "${address}" == "::1" ]]; then
            continue
        fi

        host="$(dig +short -x "${address}" 2>/dev/null | head -1)"
        if [[ -n "${host}" ]] && echo "${host}" | grep -qE "${VENDOR_PATTERN}"; then
            continue
        fi

        # Reverse DNS is frequently absent for vendor edges, so fall back to
        # matching the address against the vendors' own forward records.
        matched=""
        for vendor in api.anthropic.com claude.ai chatgpt.com api.openai.com auth.openai.com \
            generativelanguage.googleapis.com cloudcode-pa.googleapis.com oauth2.googleapis.com \
            api.x.ai cli-chat-proxy.grok.com lumo.proton.me \
            github.com raw.githubusercontent.com objects.githubusercontent.com \
            antigravity-hub-auto-updater-974169037036.us-central1.run.app; do
            if dig +short A "${vendor}" 2>/dev/null | grep -qx "${address}" ||
                dig +short AAAA "${vendor}" 2>/dev/null | grep -qix "${address}"; then
                matched="${vendor}"
                break
            fi
        done

        if [[ -n "${matched}" ]]; then
            continue
        fi

        echo "fail:ai-proxy-egress (${name} → ${address}${host:+ (${host})} is not a model vendor)"
        ((unexpected++))
    done < <(lsof -nP -i -a -p "${pid}" 2>/dev/null | awk '/ESTABLISHED/{print $9}' | sed 's/.*->//' | sort -u)

    if [[ ${unexpected} -eq 0 ]]; then
        echo "check:ai-proxy-egress (${name} reaching model vendors and loopback only)"
    else
        ((failures += unexpected))
    fi
done

if [[ ${failures} -eq 0 ]]; then
    echo "ok:ai-proxy-egress (surface reduced, egress within the vendor allowlist)"
else
    echo "fail:ai-proxy-egress (${failures} checks failed)"
    exit 1
fi
