#!/bin/bash
# Audit Codex skill roots without mutating them.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CODEX_SKILLS="${CODEX_SKILLS:-${HOME}/.codex/skills}"
AGENTS_SKILLS="${AGENTS_SKILLS:-${HOME}/.agents/skills}"
duplicates=0
identical=0
divergent=0

echo "verify:codex-skills"
echo "      codex root:  ${CODEX_SKILLS}"
echo "      agents root: ${AGENTS_SKILLS}"

if [[ ! -d "${CODEX_SKILLS}" ]]; then
    echo "warn:codex-skills (missing ${CODEX_SKILLS})"
fi

if [[ ! -d "${AGENTS_SKILLS}" ]]; then
    echo "warn:codex-skills (missing ${AGENTS_SKILLS})"
fi

if [[ ! -d "${CODEX_SKILLS}" || ! -d "${AGENTS_SKILLS}" ]]; then
    echo "ok:codex-skills (nothing to compare)"
    exit 0
fi

for codex_skill in "${CODEX_SKILLS}"/*; do
    [[ -d "${codex_skill}" ]] || continue
    name="$( basename "${codex_skill}" )"
    [[ "${name}" == .* ]] && continue

    agents_skill="${AGENTS_SKILLS}/${name}"
    [[ -d "${agents_skill}" ]] || continue

    duplicates=$((duplicates + 1))
    if diff -qr "${codex_skill}" "${agents_skill}" >/dev/null 2>&1; then
        identical=$((identical + 1))
        echo "ok:duplicate (${name} byte-identical)"
    else
        divergent=$((divergent + 1))
        echo "fail:duplicate (${name} differs)"
    fi
done

echo "summary:codex-skills (${duplicates} duplicates, ${identical} identical, ${divergent} divergent)"

if (( divergent > 0 )); then
    exit 1
fi

exit 0
