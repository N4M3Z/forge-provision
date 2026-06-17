#!/usr/bin/env bash
# Configure global Jujutsu: identity and GPG signing, sourced from git's own
# config so there is one place that holds the name, email, and signing key.
# Applied through `jj config set --user`, which writes jj's user config in the
# right location on every platform. Idempotent: re-running converges.
#
# signing.behavior is "drop" so jj does not sign on every working-copy snapshot
# (that would touch the YubiKey on nearly every command); git.sign-on-push signs
# the pushed commits in one batch instead. Under the cached touch policy that is
# one touch per push, and pushed commits still land "Verified" on GitHub.
#
# jj does not inherit git's identity or signing key at runtime; it keeps its own
# config, so these values are read from git here and written into jj.
#
# Decision: docs/decisions/ARCH-0032 (jj colocated) + ARCH-0006 (signing).
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v jj >/dev/null 2>&1; then
    echo "fail:jujutsu (jj not found; install it via the Brewfile: brew bundle --file manifests/Brewfile)"
    exit 0
fi

# jj does not create its config directory; `jj config set` errors if it is absent.
command mkdir -p "${XDG_CONFIG_HOME:-${HOME}/.config}/jj"

git_name="$(git config --global user.name 2>/dev/null)"
[[ -z "${git_name}" ]] && git_name="${GIT_NAME:-}"
git_email="$(git config --global user.email 2>/dev/null)"
[[ -z "${git_email}" ]] && git_email="${GIT_EMAIL:-}"
signing_key="$(git config --global user.signingkey 2>/dev/null)"

set_user_config() {
    local key="$1" want="$2"
    local have
    have="$(jj config get "${key}" 2>/dev/null)"
    if [[ "${have}" == "${want}" ]]; then
        echo "skip:jujutsu (${key} already ${want})"
    elif jj config set --user "${key}" "${want}"; then
        echo "config:jujutsu ${key}=${want}"
    else
        echo "fail:jujutsu (could not set ${key})"
    fi
}

if [[ -n "${git_name}" ]]; then
    set_user_config user.name "${git_name}"
else
    echo "warn:jujutsu (user.name unset in git and .env; jj commits will lack a name)"
fi

if [[ -n "${git_email}" ]]; then
    set_user_config user.email "${git_email}"
else
    echo "warn:jujutsu (user.email unset in git and .env; jj commits will lack an email)"
fi

set_user_config signing.backend gpg
set_user_config signing.behavior drop
set_user_config git.sign-on-push true

# 'jj push' gate: jj runs no git hooks, so there is no native pre-push stage.
# This alias makes `jj push` run the repo's .githooks/jj-push (gitleaks/semgrep)
# and then `jj git push`. The repo root is resolved at runtime, so one global
# definition works in every repo and clone without baking an absolute path;
# repos without a .githooks/jj-push fall through to plain `jj git push`.
# It only gates `jj push`; `jj git push` bypasses it (the real wall is GitHub
# push protection + CI).
set_user_config aliases.push '["util", "exec", "--", "bash", "-c", "cd \"$(jj workspace root)\" && if [ -x .githooks/jj-push ]; then exec .githooks/jj-push \"$@\"; else exec jj git push \"$@\"; fi", "jj-push"]'

if [[ -n "${signing_key}" ]]; then
    set_user_config signing.key "${signing_key}"
else
    echo "warn:jujutsu (git user.signingkey unset; signing.key not pinned; jj signs with the key matching user.email)"
fi

echo "ok:jujutsu"
echo "      verify: jj config list --user"
