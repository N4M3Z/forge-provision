#!/bin/bash
# Verify the configured commit-signing lane can actually sign, instead of
# discovering it at the first commit. Catches the states provisioning leaves
# behind: a signing key configured with no secret available (card not
# enrolled), a gitconfig pointing at paths from another machine, and the two
# lanes of ARCH-0006 disagreeing about gpg.format.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

format="$(git config --global gpg.format 2>/dev/null)"
signingkey="$(git config --global user.signingkey 2>/dev/null)"
gpgsign="$(git config --global commit.gpgsign 2>/dev/null)"

if [[ "${gpgsign}" != "true" ]]; then
    echo "skip:signing (commit.gpgsign is not true; nothing to verify)"
    exit 0
fi

if [[ -z "${signingkey}" ]]; then
    echo "fail:signing (commit.gpgsign=true but user.signingkey is unset)"
    exit 1
fi

# Absolute paths in gitconfig break when the file is copied between machines,
# and git reports them only when a signature is attempted. Which settings are
# load-bearing depends on the lane: the gpg.ssh.* pair is inert under
# gpg.format=openpgp, so a missing path there is a warning rather than a
# failure. A path under someone else's home is always wrong, active or not.
case "${format:-openpgp}" in
    ssh) active_paths=(gpg.ssh.program gpg.ssh.allowedSignersFile); inactive_paths=(gpg.program) ;;
    *)   active_paths=(gpg.program); inactive_paths=(gpg.ssh.program gpg.ssh.allowedSignersFile) ;;
esac

for setting in "${active_paths[@]}" "${inactive_paths[@]}"; do
    value="$(git config --global "${setting}" 2>/dev/null)"
    [[ -n "${value}" && "${value}" == /* ]] || continue

    # ${HOME%/} guards against a trailing slash making every path look foreign.
    if [[ "${value}" == /Users/* || "${value}" == /home/* ]] \
            && [[ "${value}" != "${HOME%/}/"* ]]; then
        echo "fail:signing (${setting} points into another machine's home: ${value})"
        exit 1
    fi

    [[ -e "${value}" ]] && continue

    if [[ " ${active_paths[*]} " == *" ${setting} "* ]]; then
        echo "fail:signing (${setting} points at ${value}, which does not exist on this machine)"
        exit 1
    fi
    echo "warn:signing (${setting} points at missing ${value}; unused while gpg.format=${format:-openpgp})"
done

case "${format:-openpgp}" in
    openpgp)
        if ! command -v gpg >/dev/null 2>&1; then
            echo "fail:signing (gpg.format=openpgp but gpg is not on PATH)"
            exit 1
        fi
        # A key whose private part lives on an absent card lists no secret, so
        # this is the check that distinguishes "configured" from "can sign".
        if ! gpg --list-secret-keys "${signingkey%!}" >/dev/null 2>&1; then
            echo "fail:signing (no secret key for ${signingkey} — insert the YubiKey, then 'gpg --card-status')"
            exit 1
        fi
        echo "ok:signing (openpgp, ${signingkey})"
        ;;
    ssh)
        if [[ ! -f "${signingkey}" ]]; then
            echo "fail:signing (gpg.format=ssh but ${signingkey} is not a readable public key)"
            exit 1
        fi
        echo "ok:signing (ssh, ${signingkey})"
        ;;
    *)
        echo "warn:signing (unrecognized gpg.format '${format}')"
        ;;
esac
