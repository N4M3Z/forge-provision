#!/bin/bash
# Install Apple container and bootstrap its system service.
# Idempotent: skips install if `container` is on PATH; the system start is
# safe to re-run (a running service is left as-is).
#
# Apple container runs each Linux container in its own lightweight VM via the
# Virtualization framework. It is the Linux-isolation tier for agents and
# disposable experiments (Docker-free, one VM per container). The macOS-app
# tier is Parallels (scripts/install/parallels.sh); the harness tier is the
# Claude Code Seatbelt sandbox.
#
# Requires macOS 26 (Tahoe) + Apple Silicon. The Homebrew formula installs on
# macOS 15, but container-to-container networking only works on macOS 26, so
# this script gates on the functional baseline.
#
# Reference: https://apple.github.io/container/documentation/
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "skip:container (requires Apple Silicon, found $(uname -m))"
    exit 0
fi

macos_major="$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)"
if [[ -z "${macos_major}" || "${macos_major}" -lt 26 ]]; then
    echo "skip:container (requires macOS 26, found $(sw_vers -productVersion 2>/dev/null))"
    exit 0
fi

if command -v container >/dev/null 2>&1; then
    echo "skip:container (already installed: $(command -v container))"
else
    echo "install:container"
    brew install container
fi

echo "start:container-system"
# Start via the keg path, never the linked /opt/homebrew/bin/container: the
# CLI derives CONTAINER_INSTALL_ROOT from the invoking binary's location and
# the apiserver looks for plugins under $INSTALL_ROOT/libexec/. Homebrew does
# not link libexec into the prefix, so the linked path yields an apiserver
# that exits 1 ("cannot find any plugins with type network") while every CLI
# call hangs on the launchd Mach-service lookup. Re-run after every
# `brew upgrade container`: the launchd plist records the resolved Cellar
# path, which dies with the old keg.
# --enable-kernel-install accepts the default Linux kernel download without
# an interactive prompt.
/opt/homebrew/opt/container/bin/container system start --enable-kernel-install
