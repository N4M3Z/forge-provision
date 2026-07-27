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
        # git calls gpg.program when set, so verifying whatever `gpg` resolves to
        # on PATH would check a different binary than the one that signs. That is
        # the dual-gpg divergence this script exists to catch.
        gpg_command="$(git config --global gpg.program 2>/dev/null || true)"
        gpg_command="${gpg_command:-gpg}"
        if ! command -v "${gpg_command}" >/dev/null 2>&1; then
            echo "fail:signing (gpg.format=openpgp but '${gpg_command}' is not on PATH)"
            exit 1
        fi

        key_records="$("${gpg_command}" --list-secret-keys --with-colons "${signingkey%!}" 2>/dev/null)"
        if [[ -z "${key_records}" ]]; then
            echo "fail:signing (no secret key for ${signingkey} in the keyring)"
            exit 1
        fi

        # Field 15 of a sec or ssb record carries a token serial number, so its
        # presence means the private key lives on a smartcard and the keyring
        # holds only a stub. A stub lists successfully with the card unplugged,
        # which is why listing a key proves nothing about signing: the card has
        # to answer before the next commit can succeed.
        if awk -F: '$1 ~ /^(sec|ssb)$/ && $15 != "" { found = 1 } END { exit !found }' <<< "${key_records}"; then
            if ! "${gpg_command}" --card-status >/dev/null 2>&1; then
                echo "fail:signing (${signingkey} lives on a smartcard that is not reachable — insert the YubiKey)"
                exit 1
            fi
            echo "ok:signing (openpgp, ${signingkey}, smartcard reachable)"
        else
            echo "ok:signing (openpgp, ${signingkey}, local secret key)"
        fi
        ;;
    ssh)
        # -r rather than -f: an unreadable key file is a regular file that
        # ssh-keygen still cannot sign with.
        if [[ ! -r "${signingkey}" ]]; then
            echo "fail:signing (gpg.format=ssh but ${signingkey} is not a readable public key)"
            exit 1
        fi
        echo "ok:signing (ssh, ${signingkey})"
        ;;
    x509)
        x509_program="$(git config --global gpg.x509.program 2>/dev/null || true)"
        x509_program="${x509_program:-gpgsm}"
        if ! command -v "${x509_program}" >/dev/null 2>&1; then
            echo "fail:signing (gpg.format=x509 but '${x509_program}' is not on PATH)"
            exit 1
        fi
        echo "ok:signing (x509, ${signingkey})"
        ;;
    *)
        # git accepts only openpgp, ssh, and x509. Any other value with
        # commit.gpgsign=true fails every commit, so this is not a warning.
        echo "fail:signing (gpg.format '${format}' is not one of openpgp, ssh, x509)"
        exit 1
        ;;
esac
