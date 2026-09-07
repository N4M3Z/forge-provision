#!/bin/bash
# Explicit, journaled pass-store migration with byte-for-byte verification.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
# shellcheck source=../lib/env.sh
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ $# -eq 0 || ( $# -eq 1 && "$1" == "--dry-run" ) ]]; then
    echo "skip:password-store (opt-in; see --help and docs/guides/password-store-migration.md)"
    exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "fail:password-store (Python 3.10+ is required)" >&2
    exit 1
fi
exec python3 "${SCRIPT_DIR}/../lib/password_store_migrate.py" "$@"
