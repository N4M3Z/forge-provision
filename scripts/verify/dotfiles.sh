#!/bin/bash
# Verify the deployed dotfiles match their source, so drift is reported at
# provision time rather than discovered later as a broken keybinding or a config
# nobody applied. A partial `chezmoi apply` leaves no other trace: the run that
# failed is long gone from the scrollback, and every later check passes because
# it only looks at what provisioning itself wrote.
#
# Gate on the exit status of `chezmoi verify`, never on the output of
# `chezmoi diff`. diff prints nothing for some drifted entries (a directory
# argument, entries whose difference is not textual) while verify still exits
# non-zero, so a diff-based check reports a clean machine that is not.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "skip:dotfiles (chezmoi not installed)"
    exit 0
fi

if [[ ! -d "${HOME}/.local/share/chezmoi/.git" ]]; then
    echo "skip:dotfiles (no chezmoi source; DOTFILES_REPO was never deployed)"
    exit 0
fi

if chezmoi verify >/dev/null 2>&1; then
    echo "ok:dotfiles (deployed files match the source)"
    exit 0
fi

# Two different failures land here and they need different actions, so separate
# them rather than reporting every one as drift. When the source's config
# template gains a value this machine's generated config lacks, templates cannot
# render at all: chezmoi reports nothing to apply and a naive count reads zero
# while the real answer is "unknown".
status_errors="$(mktemp "${TMPDIR:-/tmp}/dotfiles-verify.XXXXXX")" || exit 1
trap 'command rm -f "${status_errors}"' EXIT
drift="$(chezmoi status 2>"${status_errors}")"

if grep -q 'config file template has changed' "${status_errors}"; then
    echo "fail:dotfiles (this machine's chezmoi config predates the source's config template)"
    echo "      regenerate it before applying: chezmoi init"
    exit 1
fi

if grep -q 'map has no entry for key' "${status_errors}"; then
    echo "fail:dotfiles (a template needs a data value this machine's config does not define)"
    grep -o 'key "[^"]*"' "${status_errors}" | sort -u | sed 's/^/      missing /'
    echo "      add it by regenerating the config: chezmoi init"
    exit 1
fi

echo "fail:dotfiles (deployed files differ from the chezmoi source)"
echo "      $(printf '%s' "${drift}" | grep -c .) entries differ; review with: chezmoi status && chezmoi diff"
echo "      apply from a source that tracks main: a feature branch behind main"
echo "      silently reverts whatever merged since it was cut"
exit 1
