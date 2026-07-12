#!/usr/bin/env bash
# Install dcg (Destructive Command Guard) — the destructive-command net.
# Idempotent: skips when the pinned version is already on PATH.
#
# dcg is a net, not a boundary. The Seatbelt/container sandbox (VIRT-0001/0002)
# is the boundary that stops malicious or obfuscated commands; dcg catches the
# accidental ones (rm -rf, git reset --hard, dd) before an agent runs them. It
# reads a harness PreToolUse payload on stdin and emits a deny verdict.
#
# We ride the upstream signed release when one exists for the platform and build
# from the N4M3Z fork otherwise. The fork is the controlled base and patch point.
#     Upstream: https://github.com/Dicklesworthstone/destructive_command_guard
#     Fork:     https://github.com/N4M3Z/destructive_command_guard
#
# Hook wiring is deliberately NOT done here. dcg's own installer writes the live
# ~/.claude/settings.json, which chezmoi overwrites on the next apply; the Claude
# hook lives in the chezmoi source instead (see scripts/configure/dcg.sh).
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

DCG_VERSION="v0.5.7"
DCG_UPSTREAM="Dicklesworthstone/destructive_command_guard"
DCG_FORK="N4M3Z/destructive_command_guard"
INSTALL_DIR="${HOME}/.local/bin"
WORK="/tmp/claude/dcg-install"

# Pinned SHA-256 of each upstream release asset — the single source of truth for
# integrity (see the HashVerifiedExecution rule). Update both when bumping the pin.
sha_for_target() {
    case "$1" in
        aarch64-apple-darwin) echo "0fe51d2ea47d5230ae8c2d30cddbe076daa2a1be04846e9352968b0d9a5df283" ;;
        x86_64-apple-darwin)  echo "d3284f41e90b5329d52e1db97b0975797f75fd554fc306af4f00ce9cd3c691ab" ;;
        *) echo "" ;;
    esac
}

target_triple() {
    case "$(uname -s)" in
        Darwin)
            case "$(uname -m)" in
                arm64|aarch64) echo "aarch64-apple-darwin" ;;
                x86_64)        echo "x86_64-apple-darwin" ;;
            esac ;;
    esac
}

if command -v dcg >/dev/null 2>&1 \
    && [[ "$(dcg --version 2>/dev/null)" == *"${DCG_VERSION#v}"* ]]; then
    echo "skip:dcg (already ${DCG_VERSION} at $(command -v dcg))"
    exit 0
fi

build_from_fork() {
    echo "install:dcg (build from fork ${DCG_FORK} @ ${DCG_VERSION})"
    if ! command -v cargo >/dev/null 2>&1; then
        echo "fail:dcg (no pinned upstream asset for $(uname -sm), and cargo not on PATH to build the fork)"
        exit 1
    fi
    command rm -rf "${WORK}/src"
    mkdir -p "${WORK}/src"
    git clone --depth 1 --branch "${DCG_VERSION}" "https://github.com/${DCG_FORK}.git" "${WORK}/src" \
        || { echo "fail:dcg (fork clone)"; exit 1; }
    ( cd "${WORK}/src" && cargo +nightly build --release ) \
        || { echo "fail:dcg (cargo build — dcg needs nightly Rust)"; exit 1; }
    mkdir -p "${INSTALL_DIR}"
    command cp "${WORK}/src/target/release/dcg" "${INSTALL_DIR}/dcg"
    chmod +x "${INSTALL_DIR}/dcg"
    echo "ok:dcg (${DCG_VERSION} built from fork → ${INSTALL_DIR}/dcg)"
}

TARGET="$(target_triple)"
EXPECTED_SHA="$(sha_for_target "${TARGET}")"

if [[ -z "${TARGET}" || -z "${EXPECTED_SHA}" ]]; then
    build_from_fork
    exit 0
fi

echo "install:dcg (upstream ${DCG_VERSION} ${TARGET})"
mkdir -p "${INSTALL_DIR}" "${WORK}"
asset="dcg-${TARGET}.tar.xz"
url="https://github.com/${DCG_UPSTREAM}/releases/download/${DCG_VERSION}/${asset}"

curl -fsSL "${url}" -o "${WORK}/${asset}" || { echo "fail:dcg (download)"; exit 1; }

actual_sha="$(shasum -a 256 "${WORK}/${asset}" | cut -d' ' -f1)"
if [[ "${actual_sha}" != "${EXPECTED_SHA}" ]]; then
    echo "fail:dcg (sha256 mismatch — expected ${EXPECTED_SHA}, got ${actual_sha})"
    command rm -f "${WORK}/${asset}"
    exit 1
fi

# Best-effort provenance: verify the Sigstore bundle when cosign is present.
# The pinned sha256 above is the primary guarantee; this confirms the asset was
# built by the upstream repo's GitHub Actions.
if command -v cosign >/dev/null 2>&1; then
    if curl -fsSL "${url}.sigstore.json" -o "${WORK}/${asset}.sigstore.json" 2>/dev/null \
        && cosign verify-blob \
            --bundle "${WORK}/${asset}.sigstore.json" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            --certificate-identity-regexp "github.com/${DCG_UPSTREAM}" \
            "${WORK}/${asset}" >/dev/null 2>&1; then
        echo "info:dcg (cosign provenance verified)"
    else
        echo "warn:dcg (cosign present but provenance unverified — sha256 still matched)"
    fi
fi

tar xJf "${WORK}/${asset}" -C "${WORK}" || { echo "fail:dcg (extract)"; exit 1; }
command mv "${WORK}/dcg" "${INSTALL_DIR}/dcg"
chmod +x "${INSTALL_DIR}/dcg"
echo "ok:dcg (${DCG_VERSION} → ${INSTALL_DIR}/dcg)"
