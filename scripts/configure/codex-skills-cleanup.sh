#!/bin/bash
# Remove generated duplicate Codex skills only after byte-identical parity.
# Defaults to dry-run. Pass --apply to remove duplicates.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CODEX_SKILLS="${CODEX_SKILLS:-${HOME}/.codex/skills}"
AGENTS_SKILLS="${AGENTS_SKILLS:-${HOME}/.agents/skills}"
APPLY=false

for arg in "$@"; do
    case "${arg}" in
        --apply) APPLY=true ;;
        --dry-run) APPLY=false ;;
        --help|-h)
            echo "usage: scripts/configure/codex-skills-cleanup.sh [--dry-run|--apply]"
            echo "default: --dry-run"
            exit 0
            ;;
    esac
done

echo "configure:codex-skills-cleanup"
echo "      canonical root: ${CODEX_SKILLS}"
echo "      duplicate root: ${AGENTS_SKILLS}"

if [[ ! -d "${CODEX_SKILLS}" ]]; then
    echo "fail:codex-skills-cleanup (missing canonical root: ${CODEX_SKILLS})"
    exit 1
fi

if [[ ! -d "${AGENTS_SKILLS}" ]]; then
    echo "skip:codex-skills-cleanup (duplicate root missing: ${AGENTS_SKILLS})"
    exit 0
fi

removed=0
kept=0
divergent=0

for agents_skill in "${AGENTS_SKILLS}"/*; do
    [[ -d "${agents_skill}" ]] || continue
    name="$( basename "${agents_skill}" )"
    [[ "${name}" == .* ]] && continue

    codex_skill="${CODEX_SKILLS}/${name}"
    if [[ ! -d "${codex_skill}" ]]; then
        kept=$((kept + 1))
        echo "keep:codex-skills-cleanup (${name} has no canonical counterpart)"
        continue
    fi

    if ! diff -qr "${codex_skill}" "${agents_skill}" >/dev/null 2>&1; then
        divergent=$((divergent + 1))
        echo "fail:codex-skills-cleanup (${name} differs; not removing)"
        continue
    fi

    if [[ "${APPLY}" == true ]]; then
        command rm -rf "${agents_skill}"
        echo "remove:codex-skills-cleanup (${agents_skill})"
    else
        echo "dry-run:codex-skills-cleanup (would remove ${agents_skill})"
    fi
    removed=$((removed + 1))
done

echo "summary:codex-skills-cleanup (${removed} duplicate removals, ${kept} unique kept, ${divergent} divergent)"

if (( divergent > 0 )); then
    exit 1
fi

exit 0
