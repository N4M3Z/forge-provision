#!/bin/bash
# Install forge-cli from source.
# Builds via Cargo and symlinks the release binary into ~/.local/bin/forge.
# Idempotent — cargo build no-ops when source is unchanged; `ln -sf` always succeeds.
#
# Alternative not used here: download a prebuilt release from
# https://github.com/N4M3Z/forge-cli/releases — avoids needing the Rust toolchain.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FORGE_CLI_DIR="${DEV_DIR}/forge-cli"
FORGE_BIN="${HOME}/.local/bin/forge"

if [[ ! -d "${FORGE_CLI_DIR}" ]]; then
    echo "fail:forge (forge-cli not cloned at ${FORGE_CLI_DIR} — run scripts/clone/references.sh first)"
    exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "fail:forge (cargo not on PATH — run scripts/install/brew-bundle.sh to install rust)"
    exit 1
fi

# Build + install via forge-cli's Makefile (cargo build --release + ln -sf ~/.local/bin/forge)
echo "build:forge-cli"
(cd "${FORGE_CLI_DIR}" && make install) || {
    echo "fail:forge (make install failed)"
    exit 1
}

if [[ ! -x "${FORGE_BIN}" ]]; then
    echo "fail:forge (binary missing at ${FORGE_BIN} after make install)"
    exit 1
fi

echo "ok:forge"
"${FORGE_BIN}" --version
