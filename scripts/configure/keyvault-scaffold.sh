#!/usr/bin/env bash
# Scaffold the offline key-vault layout onto a mounted encrypted volume.
# Copies the non-secret docs and markers from manifests/keyvault/, substitutes
# the key ID, and creates the empty directories your secret files move into.
#
# Secret-free: it writes only docs, markers, and empty directories, never key
# material, and contains no delete — it cannot touch your *.asc / *.key files.
# Re-running overwrites the docs (including placeholders you have filled), so
# fill placeholders after the final run. Run against the mounted read-write
# container BEFORE moving any secret files in.
#
# Usage: keyvault-scaffold.sh <mounted-volume> <keyid>
#   keyvault-scaffold.sh /Volumes/GPGBackup 0xABCD1234EF567890
#
# Decision: docs/decisions/GPG-0006 Physical key backup.md
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

VOLUME="$1"
KEYID="$2"
TEMPLATE_DIR="${SCRIPT_DIR}/../../manifests/keyvault"

if [[ -z "${VOLUME}" || -z "${KEYID}" ]]; then
    echo "usage: keyvault-scaffold.sh <mounted-volume> <keyid>"
    exit 2
fi
if [[ ! -d "${VOLUME}" ]]; then
    echo "fail:keyvault (volume not mounted at ${VOLUME})"
    exit 0
fi

# Docs + markers (dotfiles included), then substitute the key ID into the .md.
# Prune hidden dirs first so the volume's .Trashes / .Spotlight-V100 system
# directories do not raise permission-denied noise.
command cp -R "${TEMPLATE_DIR}/." "${VOLUME}/"
command find "${VOLUME}" -type d -name '.*' -prune -o -name '*.md' -type f -exec sed -i '' "s/\${KEYID}/${KEYID}/g" {} +

# Directories your secret files move into — never created with content here.
command mkdir -p \
    "${VOLUME}/gpg/${KEYID}" \
    "${VOLUME}/proton/recovery" \
    "${VOLUME}/proton/pqc-mail" \
    "${VOLUME}/yubikey" \
    "${VOLUME}/ssh" \
    "${VOLUME}/tools/bin" \
    "${VOLUME}/tools/src" \
    "${VOLUME}/pass"

# Initialize the vault as a local git repo so obsolete keys can be archived in
# history and removed from the working tree. No remote, ever; commits unsigned
# (bookkeeping). The .git lives inside the encrypted container. GPG-0006.
if [[ ! -d "${VOLUME}/.git" ]]; then
    command git -C "${VOLUME}" init -q
    command git -C "${VOLUME}" config commit.gpgsign false
fi

echo "ok:keyvault (scaffolded ${VOLUME} for ${KEYID})"
echo "      next: move *.asc / *.key into gpg/${KEYID}/ and proton/, per the READMEs"
