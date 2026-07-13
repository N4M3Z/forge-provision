#!/bin/bash
# Build environment for compiling Zed from source (e.g. the fork used to test
# upstream patches). Verifies, and where possible provisions, the three macOS
# prerequisites beyond the Rust toolchain:
#   cmake            — wasmtime-c-api's build script hard-requires it (Brewfile).
#   Xcode.app        — GPUI compiles Metal shaders; Command Line Tools alone
#                      ship no `metal` compiler. Installed via the App Store,
#                      so this script only checks.
#   Metal Toolchain  — Xcode 16+ ships it as a separate downloadable component.
# Builds do not require `sudo xcode-select --switch`; export
#   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# per invocation instead, which leaves the machine default untouched.
# Reference: https://zed.dev/docs/development/macos
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

XCODE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

if ! command -v cmake >/dev/null 2>&1; then
    echo "fail:zed-dev (cmake missing; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ ! -d "${XCODE_DEVELOPER_DIR}" ]]; then
    echo "fail:zed-dev (Xcode.app missing; install from the App Store — Command Line Tools cannot compile Metal shaders)"
    exit 1
fi

if DEVELOPER_DIR="${XCODE_DEVELOPER_DIR}" xcrun metal --version >/dev/null 2>&1; then
    echo "skip:zed-dev (Metal Toolchain already installed)"
else
    echo "download:zed-dev (Metal Toolchain component, ~700 MB)"
    if ! DEVELOPER_DIR="${XCODE_DEVELOPER_DIR}" xcodebuild -downloadComponent MetalToolchain; then
        echo "fail:zed-dev (Metal Toolchain download failed)"
        exit 1
    fi
fi

echo "ok:zed-dev"
echo "      build with: DEVELOPER_DIR=${XCODE_DEVELOPER_DIR} cargo build"
