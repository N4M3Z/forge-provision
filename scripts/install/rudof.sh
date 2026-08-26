#!/usr/bin/env bash
# Install rudof — the SHACL validation gate for the declared world (DECK-0010).
# Idempotent: skips when the pinned version is already on PATH.
#
# rudof validates the artifact graph that `rune ontology export` emits against
# ontology/shapes.ttl in the runedeck repositories. It ships as a prebuilt
# release binary only: the crates.io `rudof` crate is a library with no
# binaries, and no Homebrew formula exists.
#     Upstream: https://github.com/rudof-project/rudof
#
# Note: rudof 0.3.x exits zero even on SHACL violations. The prek hook that
# consumes it greps sh:Violation in the `-r turtle` report for its exit status.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

RUDOF_VERSION="0.3.12"
RUDOF_UPSTREAM="rudof-project/rudof"
INSTALL_DIR="${HOME}/.local/bin"
WORK="/tmp/claude/rudof-install"

# Pinned SHA-256 of each upstream release asset — the single source of truth
# for integrity (see the HashVerifiedExecution rule). Update both when bumping
# the pin.
sha_for_asset() {
    case "$1" in
        "rudof_${RUDOF_VERSION}_aarch64_apple") echo "c798ea1fb41916154a5ae96d4d19eb14bf1683488e24bc7d24d547e50bba1ff6" ;;
        "rudof_${RUDOF_VERSION}_x86_64_apple")  echo "730d08a5093a197bb0e1061a9f6bf1a97371481a2ff4740f3642e2c5383a6932" ;;
        *) echo "" ;;
    esac
}

asset_name() {
    case "$(uname -s)" in
        Darwin)
            case "$(uname -m)" in
                arm64|aarch64) echo "rudof_${RUDOF_VERSION}_aarch64_apple" ;;
                x86_64)        echo "rudof_${RUDOF_VERSION}_x86_64_apple" ;;
            esac ;;
    esac
}

if command -v rudof >/dev/null 2>&1 \
    && [[ "$(rudof --version 2>/dev/null)" == *"${RUDOF_VERSION}"* ]]; then
    echo "skip:rudof (already ${RUDOF_VERSION} at $(command -v rudof))"
    exit 0
fi

ASSET="$(asset_name)"
EXPECTED_SHA="$(sha_for_asset "${ASSET}")"

if [[ -z "${ASSET}" || -z "${EXPECTED_SHA}" ]]; then
    echo "fail:rudof (no pinned upstream asset for $(uname -sm))"
    exit 1
fi

echo "install:rudof (upstream ${RUDOF_VERSION} ${ASSET})"
mkdir -p "${INSTALL_DIR}" "${WORK}"
url="https://github.com/${RUDOF_UPSTREAM}/releases/download/${RUDOF_VERSION}/${ASSET}"

curl -fsSL "${url}" -o "${WORK}/${ASSET}" || { echo "fail:rudof (download)"; exit 1; }

actual_sha="$(shasum -a 256 "${WORK}/${ASSET}" | cut -d' ' -f1)"
if [[ "${actual_sha}" != "${EXPECTED_SHA}" ]]; then
    echo "fail:rudof (sha256 mismatch — expected ${EXPECTED_SHA}, got ${actual_sha})"
    command rm -f "${WORK}/${ASSET}"
    exit 1
fi

command cp "${WORK}/${ASSET}" "${INSTALL_DIR}/rudof"
chmod +x "${INSTALL_DIR}/rudof"
command rm -f "${WORK}/${ASSET}"
echo "ok:rudof (${RUDOF_VERSION} → ${INSTALL_DIR}/rudof)"
