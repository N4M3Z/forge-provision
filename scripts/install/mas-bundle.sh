#!/bin/bash
# App Store apps from the Brewfile, through mas, with no root until an app is
# confirmed. brew bundle hands every `mas` entry to mas, and mas 7 needs root
# for each install and update, so an unattended apply stalls on sudo or fails.
# `mas list` and `mas outdated` need no root: this script reads those, reports
# each declared app as current, outdated, or missing, and acts only on an app
# you confirm. Without a terminal it reports and exits 0.
#   FORGE_MAS=yes      act on every outdated or missing app without asking
#   FORGE_MAS=report   never act
#   --ids              print the declared App Store ids and exit; brew-bundle.sh
#                      feeds them to HOMEBREW_BUNDLE_MAS_SKIP
#   [BREWFILE]         defaults to the SCOPE-selected manifest
# An app whose folder name carries a hidden mark (WhatsApp) is missing from
# `mas list`; its App Store receipt under FORGE_APPLICATIONS (/Applications)
# counts as installed instead.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

mode="${FORGE_MAS:-ask}"
case "${mode}" in
    ask|yes|report) : ;;
    *)
        echo "fail:mas (unknown FORGE_MAS '${mode}'; use yes, report, or leave unset)"
        exit 1
        ;;
esac

ids_only=0
if [[ "${1:-}" == "--ids" ]]; then
    ids_only=1
    shift
fi
BREWFILE="${1:-${FORGE_BREWFILE}}"
APPLICATIONS="${FORGE_APPLICATIONS:-/Applications}"

if [[ ! -f "${BREWFILE}" ]]; then
    echo "fail:mas (Brewfile not found at ${BREWFILE})"
    exit 1
fi

# `mas "Windows App", id: 1295203466` becomes `1295203466<TAB>Windows App`.
declared=$(awk '/^mas "/ {
    split($0, quoted, "\"")
    match($0, /id:[[:space:]]*[0-9]+/)
    id = substr($0, RSTART, RLENGTH)
    sub(/id:[[:space:]]*/, "", id)
    print id "\t" quoted[2]
}' "${BREWFILE}")

if [[ ${ids_only} -eq 1 ]]; then
    [[ -n "${declared}" ]] && cut -f1 <<< "${declared}"
    exit 0
fi

if [[ -z "${declared}" ]]; then
    echo "skip:mas (no App Store entries in ${BREWFILE##*/})"
    exit 0
fi
if ! command -v mas >/dev/null 2>&1; then
    echo "skip:mas (mas not installed; it is in the Brewfile, rerun after the bundle)"
    exit 0
fi

# Both commands print the id first; the rest of the line changes between mas
# versions, so nothing else is parsed.
installed=$(mas list 2>/dev/null | awk '{ print $1 }')
outdated=$(mas outdated 2>/dev/null | awk '{ print $1 }')

listed() { grep -qx -- "$2" <<< "$1"; }

receipt_present() {
    local receipts
    shopt -s nullglob
    receipts=("${APPLICATIONS}"/*"$1.app"/Contents/_MASReceipt/receipt)
    shopt -u nullglob
    [[ ${#receipts[@]} -gt 0 ]]
}

have_tty() { (: < /dev/tty) 2>/dev/null; }

pending=()
current=0
while IFS=$'\t' read -r id name; do
    if listed "${outdated}" "${id}"; then
        pending+=("update	${id}	${name}")
    elif listed "${installed}" "${id}" || receipt_present "${name}"; then
        current=$((current + 1))
    else
        pending+=("install	${id}	${name}")
    fi
done <<< "${declared}"

if [[ ${#pending[@]} -eq 0 ]]; then
    echo "ok:mas (${current} App Store apps installed and current)"
    exit 0
fi

failures=0
for entry in "${pending[@]}"; do
    IFS=$'\t' read -r action id name <<< "${entry}"
    case "${mode}" in
        report)
            echo "pending:mas ${name} (${action}; run with a terminal or FORGE_MAS=yes)"
            continue
            ;;
        ask)
            if ! have_tty; then
                echo "pending:mas ${name} (${action}; no terminal to ask)"
                continue
            fi
            read -r -p "mas: ${action} ${name} from the App Store? [y/N] " answer < /dev/tty
            if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
                echo "skip:mas ${name} (declined)"
                continue
            fi
            ;;
    esac
    # `upgrade` is the name mas 1.x used and an alias of `update` in mas 7.
    # mas prompts for the root password itself, now that the app is confirmed.
    subcommand="install"
    done_word="installed"
    if [[ "${action}" == "update" ]]; then
        subcommand="upgrade"
        done_word="updated"
    fi
    if mas "${subcommand}" "${id}"; then
        echo "ok:mas ${name} (${done_word})"
    else
        echo "fail:mas ${name} (${action} failed)"
        failures=$((failures + 1))
    fi
done
[[ ${failures} -eq 0 ]]
