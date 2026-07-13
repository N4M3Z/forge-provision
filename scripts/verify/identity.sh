#!/bin/bash
# Verify the global git identity is real: present, not an .env.example
# placeholder, and not a private mailbox that PROV-0008 keeps out of public
# history. The commit-time gate in .githooks/pre-commit enforces the same
# rule; this surfaces it at provision time instead of first commit.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

email="$(git config --global user.email 2>/dev/null || true)"
name="$(git config --global user.name 2>/dev/null || true)"

if [[ -z "${email}" || -z "${name}" ]]; then
    echo "fail:identity (git user.name/user.email unset — run scripts/configure/git-identity.sh)"
    exit 1
fi

case "${email}" in
    *@example.com|your-email*)
        echo "fail:identity (placeholder email '${email}' — set GIT_EMAIL in .env and re-run git-identity.sh)"
        exit 1
        ;;
    *@pm.me|*@proton.me|*@protonmail.com|*.lan)
        echo "fail:identity (private email '${email}' in global git config — use the noreply identity, PROV-0008)"
        exit 1
        ;;
esac

echo "ok:identity (${name} <${email}>)"
