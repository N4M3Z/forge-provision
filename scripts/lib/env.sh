# Source env config for forge-provision scripts.
# Loads .env if present, falls back to .env.example (committed defaults).
# Variables are exported so child processes inherit them.
# Source: https://github.com/N4M3Z/forge-provision

# Resolve repo root regardless of caller — works under bash AND zsh.
# `${BASH_SOURCE[0]}` is empty in zsh; `${(%):-%x}` is zsh-only syntax that bash
# can't parse, so we gate it with `eval` to defer zsh parsing until runtime.
if [[ -n "${BASH_VERSION:-}" ]]; then
    _self="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    eval '_self="${(%):-%x}"'
else
    _self="$0"
fi
FORGE_PROVISION_ROOT="$( cd "$( dirname "${_self}" )/../.." && pwd )"
export FORGE_PROVISION_ROOT
unset _self

# Load .env (user overrides) or .env.example (committed defaults). Auto-export.
if [[ -f "${FORGE_PROVISION_ROOT}/.env" ]]; then
    set -a
    source "${FORGE_PROVISION_ROOT}/.env"
    set +a
elif [[ -f "${FORGE_PROVISION_ROOT}/.env.example" ]]; then
    set -a
    source "${FORGE_PROVISION_ROOT}/.env.example"
    set +a
fi
