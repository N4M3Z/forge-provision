#!/bin/bash
# Configure Zed from manifests/zed/: settings.json and keymap.json copied
# into ~/.config/zed/. Copy, never symlink: in-app settings changes replace
# the file atomically, which severs symlinks (zed-industries/zed#4469).
# Idempotent: skips files already matching the manifest; divergent files are
# backed up as <name>.json.YYYY-MM-DD.bak before overwriting.
# Extensions install declaratively on next launch via auto_install_extensions.
# Reference: https://zed.dev/docs/configuring-zed
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

ZED_CONFIG="${HOME}/.config/zed"
MANIFEST_DIR="${FORGE_PROVISION_ROOT}/manifests/zed"

if ! command -v zed >/dev/null 2>&1 && [[ ! -d "/Applications/Zed.app" ]]; then
    echo "fail:zed (Zed not installed; run scripts/install/brew-bundle.sh)"
    exit 1
fi

mkdir -p "${ZED_CONFIG}"

for filename in settings.json keymap.json; do
    manifest_file="${MANIFEST_DIR}/${filename}"
    deployed_file="${ZED_CONFIG}/${filename}"

    if [[ ! -f "${manifest_file}" ]]; then
        echo "fail:zed (manifest missing at ${manifest_file})"
        exit 1
    fi

    if [[ -f "${deployed_file}" ]] && cmp -s "${manifest_file}" "${deployed_file}"; then
        echo "skip:zed (${filename} already matches manifest)"
        continue
    fi

    if [[ -f "${deployed_file}" ]]; then
        backup_file="${deployed_file}.$( date -u +%Y-%m-%d ).bak"
        echo "backup:zed (${filename} -> $( basename "${backup_file}" ))"
        cp "${deployed_file}" "${backup_file}"
    fi

    echo "copy:zed (${filename})"
    cp "${manifest_file}" "${deployed_file}"
done

echo "ok:zed"
echo "      extensions listed in auto_install_extensions install on next launch"
