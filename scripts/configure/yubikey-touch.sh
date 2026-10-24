#!/bin/bash
# Report the YubiKey OpenPGP signature-slot touch policy. The signing setup
# wants `cached`: one physical touch opens a ~15 s window that covers a whole
# batch (sign-on-push, signed/* tag sessions). Advisory only — changing the
# policy needs the admin PIN and a touch, so the command is printed, never run.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v ykman >/dev/null 2>&1; then
    echo "skip:yubikey-touch (ykman not installed — brew bundle installs it)"
    exit 0
fi

policy="$(ykman openpgp info 2>/dev/null | awk '
    /Signature key:/ { in_signature = 1; next }
    in_signature && /Touch policy:/ { print tolower($NF); exit }
')"

if [[ -z "${policy}" ]]; then
    echo "skip:yubikey-touch (no YubiKey detected or OpenPGP applet unreadable)"
    exit 0
fi

if [[ "${policy}" == "cached" || "${policy}" == "cached-fixed" ]]; then
    echo "ok:yubikey-touch (signature touch policy is ${policy})"
    exit 0
fi

echo "warn:yubikey-touch (signature touch policy is ${policy}, batch signing wants cached)"
echo "      run: ykman openpgp keys set-touch sig cached   (admin PIN + touch required)"
