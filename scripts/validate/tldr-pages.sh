#!/bin/bash
# Validate forge-provision's strict tealdeer pages without network access.
# Full pages follow the tldr page structure. Patch pages contain examples only,
# because tealdeer appends them to an upstream page.
# Source: https://github.com/N4M3Z/forge-provision

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

PAGES_DIR="${FORGE_PROVISION_ROOT}/docs/tldr-pages"
INVENTORY="${PAGES_DIR}/inventory.tsv"
failures=0

fail() {
    echo "fail:tldr-pages ($1)"
    failures=$(( failures + 1 ))
}

if [[ ! -d "${PAGES_DIR}" ]]; then
    echo "fail:tldr-pages (page directory missing at ${PAGES_DIR})"
    exit 1
fi

if [[ ! -f "${INVENTORY}" ]]; then
    echo "fail:tldr-pages (inventory missing at ${INVENTORY})"
    exit 1
fi

header="$(LC_ALL=C command head -n 1 "${INVENTORY}")"
if [[ "${header}" != $'command\tstate\tguide\treason' ]]; then
    fail "inventory header must be command, state, guide, reason"
fi

validate_examples() {
    local file="$1"
    local relative="${file#"${FORGE_PROVISION_ROOT}/"}"
    local descriptions commands

    descriptions="$(command grep -cE '^- .+:$' "${file}" || true)"
    commands="$(command grep -cE '^`[^`]+`$' "${file}" || true)"

    if [[ "${descriptions}" -lt 1 ]]; then
        fail "${relative} has no example description"
    fi
    if [[ "${commands}" -lt 1 ]]; then
        fail "${relative} has no command example"
    fi
    if [[ "${descriptions}" -ne "${commands}" ]]; then
        fail "${relative} has ${descriptions} descriptions but ${commands} commands"
    fi
    if [[ "${descriptions}" -gt 8 ]]; then
        fail "${relative} exceeds eight examples"
    fi
}

while IFS= read -r file; do
    name="$(basename "${file}")"
    case "${name}" in
        *.page.md)
            command_name="${name%.page.md}"
            first_line="$(LC_ALL=C command head -n 1 "${file}")"
            if [[ "${first_line}" != "# ${command_name}" ]]; then
                fail "${name} must start with '# ${command_name}'"
            fi
            if ! command grep -qE '^> .+' "${file}"; then
                fail "${name} needs a quoted description"
            fi
            validate_examples "${file}"
            ;;
        *.patch.md)
            command_name="${name%.patch.md}"
            if command grep -qE '^# |^> ' "${file}"; then
                fail "${name} must contain examples only"
            fi
            validate_examples "${file}"
            ;;
        inventory.tsv) ;;
        *) fail "unsupported file suffix: ${name}" ;;
    esac

done < <(find "${PAGES_DIR}" -maxdepth 1 -type f | LC_ALL=C sort)

while IFS= read -r full_page; do
    command_name="$(basename "${full_page}" .page.md)"
    if [[ -f "${PAGES_DIR}/${command_name}.patch.md" ]]; then
        fail "${command_name} has both a full page and a patch page"
    fi
done < <(find "${PAGES_DIR}" -maxdepth 1 -type f -name '*.page.md' | LC_ALL=C sort)

duplicates="$(command tail -n +2 "${INVENTORY}" | command cut -f1 | LC_ALL=C sort | uniq -d)"
if [[ -n "${duplicates}" ]]; then
    while IFS= read -r duplicate; do
        [[ -n "${duplicate}" ]] && fail "duplicate inventory command: ${duplicate}"
    done <<< "${duplicates}"
fi

while IFS=$'\t' read -r command_name state guide reason extra; do
    [[ "${command_name}" == "command" ]] && continue
    if [[ -z "${command_name}" || -z "${state}" || -z "${guide}" || -z "${reason}" || -n "${extra:-}" ]]; then
        fail "invalid inventory row for ${command_name:-unknown}"
        continue
    fi

    case "${state}" in
        full)
            [[ -f "${PAGES_DIR}/${command_name}.page.md" ]] \
                || fail "inventory expects ${command_name}.page.md"
            ;;
        patch)
            [[ -f "${PAGES_DIR}/${command_name}.patch.md" ]] \
                || fail "inventory expects ${command_name}.patch.md"
            ;;
        upstream|exempt) ;;
        *) fail "${command_name} has unknown inventory state ${state}" ;;
    esac

    if [[ "${guide}" != "-" && ! -f "${FORGE_PROVISION_ROOT}/${guide}" ]]; then
        fail "${command_name} links to missing guide ${guide}"
    fi
done < "${INVENTORY}"

while IFS= read -r page; do
    name="$(basename "${page}")"
    case "${name}" in
        *.page.md) command_name="${name%.page.md}"; expected_state="full" ;;
        *.patch.md) command_name="${name%.patch.md}"; expected_state="patch" ;;
        *) continue ;;
    esac

    state="$(command awk -F '\t' -v command_name="${command_name}" \
        '$1 == command_name { print $2; exit }' "${INVENTORY}")"
    if [[ "${state}" != "${expected_state}" ]]; then
        fail "${name} has no matching ${expected_state} inventory entry"
    fi
done < <(find "${PAGES_DIR}" -maxdepth 1 -type f \( -name '*.page.md' -o -name '*.patch.md' \) | LC_ALL=C sort)

if [[ "${failures}" -gt 0 ]]; then
    echo "fail:tldr-pages (${failures} checks failed)"
    exit 1
fi

echo "ok:tldr-pages (strict pages and inventory valid)"
