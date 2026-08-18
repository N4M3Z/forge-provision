#!/bin/bash
# Point tealdeer at forge-provision's strict custom-page source. The update
# preserves every unrelated TOML line and changes only custom_pages_dir.
# Source: https://github.com/N4M3Z/forge-provision

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

PAGES_DIR="${FORGE_PROVISION_ROOT}/docs/tldr-pages"
VALIDATOR="${FORGE_PROVISION_ROOT}/scripts/validate/tldr-pages.sh"

if ! command -v tldr >/dev/null 2>&1; then
    echo "fail:tldr-pages (tldr not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

"${VALIDATOR}"

show_paths="$(NO_COLOR=1 tldr --show-paths 2>/dev/null || true)"
config_file="$(printf '%s\n' "${show_paths}" | command awk '
    match($0, /\/.*config\.toml/) { print substr($0, RSTART, RLENGTH); exit }
')"

if [[ -z "${config_file}" ]]; then
    config_dir="${TEALDEER_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/tealdeer}"
    config_file="${config_dir}/config.toml"
fi

config_dir="$(dirname "${config_file}")"
mkdir -p "${config_dir}"

if [[ "${PAGES_DIR}" == *$'\n'* || "${PAGES_DIR}" == *'"'* ]]; then
    echo "fail:tldr-pages (custom page path contains unsupported characters)"
    exit 1
fi

if [[ ! -f "${config_file}" ]]; then
    printf '[directories]\ncustom_pages_dir = "%s"\n' "${PAGES_DIR}" > "${config_file}"
    echo "write:tldr-pages (${config_file})"
else
    temporary="$(mktemp "${config_dir}/config.toml.XXXXXX")"
    trap 'rm -f "${temporary}"' EXIT

    command awk -v value="${PAGES_DIR}" '
        BEGIN { in_directories = 0; wrote = 0 }
        /^[[:space:]]*custom_pages_dir[[:space:]]*=/ {
            if (!wrote) {
                print "custom_pages_dir = \"" value "\""
                wrote = 1
            }
            next
        }
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
            if (in_directories && !wrote) {
                print "custom_pages_dir = \"" value "\""
                wrote = 1
            }
            in_directories = ($0 ~ /^[[:space:]]*\[directories\][[:space:]]*$/)
            print
            next
        }
        { print }
        END {
            if (!wrote) {
                if (!in_directories) {
                    print ""
                    print "[directories]"
                }
                print "custom_pages_dir = \"" value "\""
            }
        }
    ' "${config_file}" > "${temporary}"

    chmod --reference="${config_file}" "${temporary}" 2>/dev/null || chmod 600 "${temporary}"
    mv "${temporary}" "${config_file}"
    trap - EXIT
    echo "update:tldr-pages (${config_file})"
fi

if ! NO_COLOR=1 tldr --show-paths | command grep -Fq "${PAGES_DIR}"; then
    echo "fail:tldr-pages (tealdeer did not report ${PAGES_DIR})"
    exit 1
fi

echo "ok:tldr-pages (${PAGES_DIR})"
