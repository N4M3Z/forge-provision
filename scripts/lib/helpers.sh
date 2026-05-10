#!/bin/bash
# Helper functions for check.sh

# Output formatting
output() { printf "  %b  %s ${BLUE}(%s)${RESET}\n" "$1" "$2" "$3"; }

# Execute check script
run() { "$DIR/$1.sh" 2>/dev/null; }

# Get line N from $data (with optional default)
line() { local val=$(echo "$data" | sed -n "${1}p"); echo "${val:-${2}}"; }

# Get value for key:value format
key() { echo "$data" | grep "^$1:" | cut -d: -f2-; }

# Get value with default
val() { local v="$1"; echo "${v:-$2}"; }

# Blank line
br() { echo " "; }

# Result helpers. Severity codes follow Nagios convention plus UNKNOWN (see ADR-0003):
# 0 = OK/Pass        (green ✓)
# 1 = Warning        (yellow !)
# 2 = Critical/Fail  (red ✗)
# 3 = Info           (blue ℹ)
# 4 = Unknown        (cyan ?)
pass()    { output "$CHECK_PASS"    "$1" "$2"; }
fail()    { output "$CHECK_FAIL"    "$1" "$2"; ((issues++)); }
warn()    { output "$CHECK_WARN"    "$1" "$2"; ((issues++)); }
info()    { output "$CHECK_INFO"    "$1" "$2"; }
unknown() { output "$CHECK_UNKNOWN" "$1" "$2"; ((unknowns++)); }

# Evaluate check result based on severity code
check() {
    local code="$1"
    local label="$2"
    local pass_msg="$3"
    local fail_msg="$4"

    case "$code" in
        0) pass    "$label" "$pass_msg" ;;
        1) warn    "$label" "$fail_msg" ;;
        2) fail    "$label" "$fail_msg" ;;
        3) info    "$label" "$fail_msg" ;;
        4) unknown "$label" "Indeterminate" ;;
        *) unknown "$label" "Invalid code" ;;
    esac
}
