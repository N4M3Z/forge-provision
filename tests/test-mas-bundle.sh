#!/bin/bash
# Regression tests for scripts/install/mas-bundle.sh against a stub mas: the
# declared ids, the current/outdated/missing split, the receipt fallback for an
# app folder with a hidden mark, the report mode, and the yes mode with a
# failing install. The real mas and App Store are never touched.
# Source: https://github.com/N4M3Z/forge-provision

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SCRIPT="${ROOT}/scripts/install/mas-bundle.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mas-bundle.XXXXXX") || exit 1
trap 'command rm -rf "$WORK"' EXIT
failures=0

fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

pass() {
    echo "PASS: $1"
}

assert_output() {
    local label="$1" expected="$2" actual="$3"
    if [[ "${actual}" == *"${expected}"* ]]; then
        pass "${label}"
    else
        fail "${label} (expected '${expected}' in: ${actual})"
    fi
}

assert_true() { # label, then a test(1) expression
    local label="$1"
    shift
    if test "$@"; then
        pass "${label}"
    else
        fail "${label}"
    fi
}

mkdir -p "${WORK}/bin" "${WORK}/apps"
cat > "${WORK}/bin/mas" <<'STUB'
#!/bin/bash
case "$1" in
    list) cat "${MAS_STUB_LIST}" ;;
    outdated) cat "${MAS_STUB_OUTDATED}" ;;
    install|upgrade)
        echo "$1 $2" >> "${MAS_STUB_LOG}"
        [[ "$2" == "${MAS_STUB_FAIL:-}" ]] && exit 1
        exit 0
        ;;
    *) exit 2 ;;
esac
STUB
chmod +x "${WORK}/bin/mas"

printf '%s\n' \
    '# comment' \
    'cask "firefox"' \
    'mas "Windows App",            id: 1295203466' \
    'mas "WhatsApp",  id: 310633997' \
    'brew "jq"' > "${WORK}/Brewfile"

run() { # list, outdated, mode, then extra env assignments
    local list="$1" outdated="$2" mode="$3"
    shift 3
    printf '%b' "${list}" > "${WORK}/list"
    printf '%b' "${outdated}" > "${WORK}/outdated"
    : > "${WORK}/log"
    env "$@" PATH="${WORK}/bin:${PATH}" FORGE_MAS="${mode}" FORGE_APPLICATIONS="${WORK}/apps" \
        MAS_STUB_LIST="${WORK}/list" MAS_STUB_OUTDATED="${WORK}/outdated" MAS_STUB_LOG="${WORK}/log" \
        bash "${SCRIPT}" "${WORK}/Brewfile" 2>/dev/null
}

ids=$(bash "${SCRIPT}" --ids "${WORK}/Brewfile" 2>/dev/null | tr '\n' ' ')
assert_true "ids (got '${ids}')" "${ids}" = "1295203466 310633997 "

out=$(run '1295203466 Windows App (11.1)\n310633997 WhatsApp (26.38)\n' '' report)
assert_output "all current" "ok:mas (2 App Store apps installed and current)" "${out}"
assert_true "all current: no action" ! -s "${WORK}/log"

mkdir -p "${WORK}/apps/$(printf '\xe2\x80\x8e')WhatsApp.app/Contents/_MASReceipt"
: > "${WORK}/apps/$(printf '\xe2\x80\x8e')WhatsApp.app/Contents/_MASReceipt/receipt"
out=$(run '1295203466 Windows App (11.1)\n' '' report)
assert_output "receipt fallback" "ok:mas (2 App Store apps installed and current)" "${out}"
command rm -rf "${WORK}/apps"/*

out=$(run '1295203466 Windows App (11.1)\n' '1295203466 Windows App (11.1 -> 11.2)\n' report)
assert_output "report: outdated" "pending:mas Windows App (update;" "${out}"
assert_output "report: missing" "pending:mas WhatsApp (install;" "${out}"
assert_true "report: no action" ! -s "${WORK}/log"

out=$(run '1295203466 Windows App (11.1)\n' '1295203466 Windows App (11.1 -> 11.2)\n' yes)
assert_output "yes: updated" "ok:mas Windows App (updated)" "${out}"
assert_output "yes: installed" "ok:mas WhatsApp (installed)" "${out}"
log=$(tr '\n' ' ' < "${WORK}/log")
assert_true "yes: mas calls (got '${log}')" "${log}" = "upgrade 1295203466 install 310633997 "

out=$(run '' '' yes MAS_STUB_FAIL=310633997)
status=$?
assert_output "yes: failure reported" "fail:mas WhatsApp (install failed)" "${out}"
assert_true "yes: failure exit (got ${status})" "${status}" -ne 0

out=$(run '' '' bogus)
assert_output "unknown mode" "fail:mas (unknown FORGE_MAS 'bogus'" "${out}"

if ! (: < /dev/tty) 2>/dev/null; then
    out=$(run '' '' ask)
    assert_output "ask without terminal" "pending:mas WhatsApp (install; no terminal to ask)" "${out}"
    assert_true "ask without terminal: no action" ! -s "${WORK}/log"
fi

if [[ ${failures} -gt 0 ]]; then
    echo "test-mas-bundle: ${failures} failure(s)"
    exit 1
fi
echo "test-mas-bundle: all passed"
