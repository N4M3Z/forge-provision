#!/bin/bash
# Install Xcode Command Line Tools.
# Idempotent: skips if `xcode-select -p` returns an installed path.
# Note: `xcode-select --install` opens a GUI prompt; user must click "Install" once.
# Reference: https://developer.apple.com/xcode/resources/
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if xcode-select -p >/dev/null 2>&1; then
    echo "skip:xcode-cli (already installed: $(xcode-select -p))"
    exit 0
fi

echo "install:xcode-cli"
xcode-select --install
