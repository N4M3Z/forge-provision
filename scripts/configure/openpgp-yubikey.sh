#!/bin/bash
# Opt-in encrypted-vault OpenPGP ceremony; never run as part of baseline setup.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
# shellcheck source=../lib/env.sh
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ $# -eq 0 || ( $# -eq 1 && "$1" == "--dry-run" ) ]]; then
    echo "skip:openpgp-yubikey (opt-in; see --help and docs/guides/openpgp-yubikey.md)"
    exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "fail:openpgp-yubikey (Python 3.10+ is required)" >&2
    exit 1
fi
exec python3 "${SCRIPT_DIR}/../lib/openpgp_setup.py" "$@"
