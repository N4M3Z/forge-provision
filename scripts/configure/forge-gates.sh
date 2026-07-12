#!/usr/bin/env bash
# Retrofit the forge secret-scan gate into the forge module repos so it fires
# under both git pre-push and jj push.
#
# jj runs no git hooks, so the pre-push-staged gitleaks/semgrep gate is dormant
# on every jj-colocated repo. This deploys the new .githooks/pre-push (git users)
# and .githooks/jj-push (the jj `push` alias payload), refreshes the deprecated
# `gitleaks detect` invocation, and wires both triggers: git core.hooksPath and
# the repo-local jj `push` alias. Idempotent: re-running converges.
#
# The git/jj wiring is applied directly rather than via `make install`, which
# would also re-deploy each module's content. The module Makefiles are left
# untouched (customization risk) and reported so they can adopt the jj-aware
# install target on their own schedule.
#
# Decision: docs/decisions/ARCH-0032 (jj colocated) + forge-cli forge init.
#
# Source: https://github.com/N4M3Z/forge-provision
#
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FORGE_CLI="${DEV_DIR}/forge-cli"
TEMPLATES="${FORGE_CLI}/templates/init"
VALIDATE_SHA="$(shasum -a 256 "${FORGE_CLI}/scripts/validate.sh" 2>/dev/null | command cut -d' ' -f1)"

if [[ -z "${VALIDATE_SHA}" || ! -d "${TEMPLATES}/.githooks" ]]; then
    echo "fail:forge-gates (forge-cli templates or validate.sh missing under ${FORGE_CLI})"
    exit 0
fi

deploy_hook() {
    local repo="$1" hook="$2"
    command mkdir -p "${repo}/.githooks"
    command sed "s/\${VALIDATE_SH_SHA}/${VALIDATE_SHA}/g" \
        "${TEMPLATES}/.githooks/${hook}" > "${repo}/.githooks/${hook}"
}

for repo in "${DEV_DIR}"/forge-*/ ; do
    repo="${repo%/}"
    [[ -d "${repo}/.git" ]] || continue
    name="$(command basename "${repo}")"

    # Hooks: pre-push + jj-push are new (always deploy); pre-commit only if absent.
    [[ -f "${repo}/.githooks/pre-commit" ]] || deploy_hook "${repo}" pre-commit
    deploy_hook "${repo}" pre-push
    deploy_hook "${repo}" jj-push
    command chmod +x "${repo}/.githooks/"* 2>/dev/null

    # Check definitions: deploy full set if absent, else refresh the gitleaks line.
    if [[ -f "${repo}/.pre-commit-config.yaml" ]]; then
        command sed -i '' 's|entry: gitleaks .*|entry: gitleaks detect --no-banner|' \
            "${repo}/.pre-commit-config.yaml"
        gate="refreshed"
    else
        command cp "${TEMPLATES}/.pre-commit-config.yaml" "${repo}/.pre-commit-config.yaml"
        gate="deployed"
    fi
    # .gitleaks.toml must extend the default ruleset; an allowlist-only config
    # silently disables every rule. Deploy the template, or repair in place.
    if [[ -f "${repo}/.gitleaks.toml" ]]; then
        if ! command grep -q 'useDefault' "${repo}/.gitleaks.toml"; then
            { printf '[extend]\nuseDefault = true\n\n'; command cat "${repo}/.gitleaks.toml"; } \
                > "${repo}/.gitleaks.toml.tmp"
            command mv "${repo}/.gitleaks.toml.tmp" "${repo}/.gitleaks.toml"
        fi
    else
        command cp "${TEMPLATES}/.gitleaks.toml" "${repo}/.gitleaks.toml"
    fi

    # Trigger 1 (git): point git at the repo hooks.
    command git -C "${repo}" config core.hooksPath .githooks

    # Trigger 2 (jj): repo-local `push` alias -> the committed jj-push wrapper.
    if [[ -d "${repo}/.jj" ]] && command -v jj >/dev/null 2>&1; then
        if jj -R "${repo}" config set --repo aliases.push \
            "[\"util\",\"exec\",\"--\",\"bash\",\"${repo}/.githooks/jj-push\"]" 2>/dev/null; then
            jjwire="jj-push wired"
        else
            jjwire="jj alias FAILED"
        fi
    else
        jjwire="no .jj"
    fi

    # Report whether the Makefile already wires jj on `make install` (else manual follow-up).
    if command grep -q 'aliases.push' "${repo}/Makefile" 2>/dev/null; then
        mk="Makefile jj-aware"
    else
        mk="Makefile needs jj-aware install target"
    fi

    echo "ok:forge-gates ${name} (gate ${gate}; git hooksPath set; ${jjwire}; ${mk})"
done

echo "ok:forge-gates (validate.sh SHA ${VALIDATE_SHA:0:12}…)"
