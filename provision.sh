#!/bin/bash
# forge-provision orchestrator — mirrors check-mac/check.sh
# Runs every script in the verb directories under scripts/, in dependency
# order (install before clone before migrate before configure before verify).
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="${SCRIPT_DIR}/scripts/lib"

# Source env first (DEV_DIR, OLD_CLAUDE_DIR, GITHUB_USER, etc.)
source "${LIB_DIR}/env.sh"

# Source helpers if present (lands after bootstrap copies them from check-mac)
[[ -f "${LIB_DIR}/helpers.sh" ]] && source "${LIB_DIR}/helpers.sh"

# Default run: bring THIS machine to baseline. migrate/ (old-Mac state) and
# clone/ (reference repos) are opt-in via --topic — they assume context a
# fresh machine does not have.
TOPIC_ORDER=(install configure verify)
OPT_IN_TOPICS=(clone migrate)

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Options:
    --dry-run        List the scripts that would run; mutate nothing
    --strict         Exit non-zero if any script fails
    --topic <name>   Run only the named topic (subdir of scripts/)
    -h, --help       Show this help

Default topics, in order: ${TOPIC_ORDER[*]}
Opt-in via --topic only:  ${OPT_IN_TOPICS[*]}
Scope: SCOPE=work in .env selects the corporate subset (Brewfile.work,
work Bunfile, personal-lane scripts skip themselves).
USAGE
}

DRY_RUN=""
STRICT=0
TOPIC=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --strict)  STRICT=1 ;;
        --topic)
            TOPIC="${2:-}"
            if [[ -z "${TOPIC}" ]]; then
                echo "fail:provision (--topic requires a name)"
                exit 2
            fi
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "fail:provision (unknown option: $1)"
            usage
            exit 2
            ;;
    esac
    shift
done

if [[ -n "${TOPIC}" ]]; then
    if [[ ! -d "${SCRIPT_DIR}/scripts/${TOPIC}" || "${TOPIC}" == "lib" ]]; then
        echo "fail:provision (no such topic: ${TOPIC})"
        exit 2
    fi
    topics=("${TOPIC}")
else
    topics=()
    for topic in "${TOPIC_ORDER[@]}"; do
        [[ -d "${SCRIPT_DIR}/scripts/${topic}" ]] && topics+=("${topic}")
    done
fi

failures=0
ran=0

for topic in "${topics[@]}"; do
    echo "== topic:${topic}"
    for script in "${SCRIPT_DIR}/scripts/${topic}"/*.sh; do
        [[ -f "${script}" ]] || continue
        name="${topic}/$(basename "${script}")"
        if [[ -n "${DRY_RUN}" ]]; then
            echo "would-run:${name}"
            continue
        fi
        echo "-- run:${name}"
        if bash "${script}"; then
            ((ran++))
        else
            echo "fail:${name} (exit $?)"
            ((failures++))
        fi
    done
done

if [[ -n "${DRY_RUN}" ]]; then
    echo "ok:provision (dry-run; nothing mutated)"
    exit 0
fi

if [[ ${failures} -gt 0 ]]; then
    echo "done:provision (${ran} succeeded, ${failures} failed)"
    [[ ${STRICT} -eq 1 ]] && exit 1
    exit 0
fi

echo "ok:provision (${ran} scripts succeeded)"
