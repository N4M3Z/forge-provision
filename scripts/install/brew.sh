#!/bin/bash
# Install Homebrew.
# Idempotent: skips if `brew` is already on PATH or installed at the standard prefix.
# Note: the upstream installer triggers `xcode-select --install` if Command Line Tools are missing.
# Reference: https://brew.sh
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if command -v brew >/dev/null 2>&1; then
    echo "skip:brew (already installed: $(command -v brew))"
    exit 0
fi

# Apple Silicon
if [[ -x /opt/homebrew/bin/brew ]]; then
    echo "skip:brew (installed at /opt/homebrew/bin/brew but not on PATH)"
    echo "      add to shell init: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
    exit 0
fi

# Intel
if [[ -x /usr/local/bin/brew ]]; then
    echo "skip:brew (installed at /usr/local/bin/brew but not on PATH)"
    exit 0
fi

echo "install:brew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
