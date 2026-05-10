#!/bin/bash
# forge-provision orchestrator — mirrors check-mac/check.sh
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="${SCRIPT_DIR}/scripts/lib"

# Source env first (DEV_DIR, OLD_CLAUDE_DIR, GITHUB_USER, etc.)
source "${LIB_DIR}/env.sh"

# Source helpers if present (lands after bootstrap copies them from check-mac)
[[ -f "${LIB_DIR}/helpers.sh" ]] && source "${LIB_DIR}/helpers.sh"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Options:
    --dry-run        Print what would happen; mutate nothing
    --strict         Exit non-zero on any non-OK
    --topic <name>   Run only the named topic (subdir of scripts/)
    -h, --help       Show this help

Topics (so far): bootstrap, claude
USAGE
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

echo "forge-provision orchestrator — stub. Topic scripts not yet wired up."
echo "Run individual scripts directly from scripts/<topic>/ for now."
