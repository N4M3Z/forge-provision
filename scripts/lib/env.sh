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

# Tools installed to ~/.local/bin (dcg, forge, chezmoi externals) are callable
# later in the SAME provision run, before the shell rc that adds this to PATH
# has been deployed. Same fix-class as brew shellenv.
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) : ;;
    *) PATH="${HOME}/.local/bin:${PATH}"; export PATH ;;
esac

# Load .env (user overrides) or .env.example (committed defaults). Auto-export.
if [[ -f "${FORGE_PROVISION_ROOT}/.env" ]]; then
    set -a
    source "${FORGE_PROVISION_ROOT}/.env"
    set +a
elif [[ -f "${FORGE_PROVISION_ROOT}/.env.example" ]]; then
    set -a
    source "${FORGE_PROVISION_ROOT}/.env.example"
    set +a
    # Placeholder values are fine for path lookups but wrong for anything
    # identity-bearing; consumers check this flag before writing identity.
    export FORGE_ENV_DEFAULTS=1
    echo "warn:env (.env missing; using .env.example placeholders — cp .env.example .env and edit)" >&2
fi

# Validate SCOPE once, here, so an unknown value fails closed everywhere
# instead of silently falling through to the full personal manifest.
case "${SCOPE:-}" in
    ""|full|work) : ;;
    *)
        echo "fail:env (unknown SCOPE '${SCOPE}'; use 'work', 'full', or leave unset)" >&2
        exit 1
        ;;
esac

# The manifest the active SCOPE selects. Everything that applies or checks the
# bundle (brew-bundle.sh, verify scripts, INSTALL.md commands) uses this.
if [[ "${SCOPE:-}" == "work" ]]; then
    FORGE_BREWFILE="${FORGE_PROVISION_ROOT}/manifests/Brewfile.work"
else
    FORGE_BREWFILE="${FORGE_PROVISION_ROOT}/manifests/Brewfile"
fi
export FORGE_BREWFILE

# Personal-lane gate. Scripts whose payload belongs only on the owner's personal
# machine call `require_scope full` right after sourcing env.sh; on a work-scoped
# machine they skip instead of installing.
require_scope() {
    if [[ "$1" == "full" && "${SCOPE:-}" == "work" ]]; then
        echo "skip:$(basename "${0%.sh}") (personal scope; SCOPE=work)"
        exit 0
    fi
}
