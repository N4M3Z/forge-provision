# Source env config for forge-provision scripts.
# Loads .env if present, falls back to .env.example (committed defaults).
# Variables are exported so child processes inherit them.
# Source: https://github.com/N4M3Z/forge-provision

# Resolve repo root regardless of caller (two levels up from scripts/lib/).
FORGE_PROVISION_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
export FORGE_PROVISION_ROOT

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
