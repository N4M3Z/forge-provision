#!/bin/bash
# Verify metadata only. Zed owns the credential content, while chezmoi applies
# a chmod-only convergence script so no secret enters the provision repository.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

credentials="${HOME}/.config/zed/development_credentials"

if [[ ! -e "${credentials}" ]]; then
    echo "skip:zed-credentials (file does not exist)"
    exit 0
fi

mode="$(stat -f '%Lp' "${credentials}")"
if [[ "${mode}" != "600" ]]; then
    echo "fail:zed-credentials (mode is ${mode}; run chezmoi apply)"
    exit 1
fi

if chezmoi source-path "${credentials}" >/dev/null 2>&1; then
    echo "fail:zed-credentials (secret content must not be chezmoi-managed)"
    exit 1
fi

echo "ok:zed-credentials (mode 0600; content unmanaged)"
