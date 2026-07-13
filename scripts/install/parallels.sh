#!/usr/bin/env bash
# Install Parallels Desktop from its official DMG.
# Idempotent: skips if /Applications/Parallels Desktop.app exists.
#
# Parallels is NOT a drag-to-Applications app. The DMG carries an installer
# stub ("Install Parallels Desktop.app") that downloads and installs the full
# application, requires admin rights, and prompts for license activation. This
# script automates the download + mount + stub-launch; activation and the
# kernel-extension / system-extension approval must be completed in the GUI.
#
# Decision: docs/decisions/PROV-0009 (setup) + ARCH-0014 (DMG vs cask) +
# ARCH-0016 (when to adopt Parallels at all).
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
[[ -f "${SCRIPT_DIR}/../lib/helpers.sh" ]] && source "${SCRIPT_DIR}/../lib/helpers.sh"

APP_NAME="Parallels Desktop"
# Official v26 direct DMG link (carries the installer stub, ~600 MB).
# Bump the version path when adopting a newer major release.
DMG_URL="https://link.parallels.com/pdfm/v26/dmg-download/"
APP_PATH="/Applications/${APP_NAME}.app"
INSTALLER_STUB="Install Parallels Desktop.app"

if [[ -d "${APP_PATH}" ]]; then
    echo "skip:parallels (already at ${APP_PATH})"
    exit 0
fi

echo "install:parallels (fetching latest DMG)"

TMP_DMG="$(mktemp -d)/parallels.dmg"
MOUNT_POINT="$(mktemp -d)"

cleanup() {
    hdiutil detach "${MOUNT_POINT}" >/dev/null 2>&1 || true
    rm -rf "$(dirname "${TMP_DMG}")" "${MOUNT_POINT}"
}
trap cleanup EXIT

if [[ -n "${DRY_RUN:-}" ]]; then
    echo "  would download ${DMG_URL}, mount it, and launch the installer stub"
    echo "skip:parallels (dry-run)"
    exit 0
fi

command curl -fSL "${DMG_URL}" -o "${TMP_DMG}" || {
    echo "fail:parallels (DMG download failed)"
    exit 1
}

hdiutil attach "${TMP_DMG}" -mountpoint "${MOUNT_POINT}" -nobrowse -quiet

if [[ ! -d "${MOUNT_POINT}/${INSTALLER_STUB}" ]]; then
    echo "fail:parallels (installer stub not found at ${MOUNT_POINT}/${INSTALLER_STUB})"
    echo "      the DMG layout may have changed; download manually from ${DMG_URL}"
    exit 1
fi

# The stub is a GUI installer requiring admin auth and system-extension
# approval — it cannot complete headlessly. Launch it and hand off.
open -W "${MOUNT_POINT}/${INSTALLER_STUB}"

if [[ -d "${APP_PATH}" ]]; then
    echo "ok:parallels (installed to ${APP_PATH})"
else
    echo "warn:parallels (installer launched; ${APP_PATH} not yet present)"
    echo "      complete the GUI installer if it is still running"
fi

echo ""
echo "      Post-install (manual, GUI / admin required):"
echo "      1. Approve the Parallels system extension in System Settings > Privacy & Security"
echo "      2. Activate the license: prlsrvctl install-license -k <KEY>  (or sign in via the GUI)"
echo "      3. VM setup + recommended settings: see docs/decisions/PROV-0009"
