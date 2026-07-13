#!/bin/bash
# Install PostgreSQL 17 + pgvector and start Postgres as a background service.
# Idempotent: skips a brew install when the formula is present; the service start
# is safe to re-run (an already-running service is left as-is).
#
# Postgres is the brain's index tier: gbrain stores pages, chunks, embeddings,
# and the link graph in a `brain` database, with pgvector providing vector
# similarity search. Local Postgres (not PGLite) is required for concurrent
# MCP + CLI + TUI access. Creating the `brain` database and `CREATE EXTENSION
# vector` are application bring-up (see the gbrain local-setup runbook in
# forge-data), not base provisioning, so they are intentionally left out here.
#
# Reference: https://github.com/pgvector/pgvector
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

if brew list postgresql@17 >/dev/null 2>&1; then
    echo "skip:postgresql@17 (already installed)"
else
    echo "install:postgresql@17"
    brew install postgresql@17
fi

if brew list pgvector >/dev/null 2>&1; then
    echo "skip:pgvector (already installed)"
else
    echo "install:pgvector"
    brew install pgvector
fi

echo "start:postgresql@17-service"
# launchd service so it restarts at login. `brew services start` is idempotent:
# an already-running service reports "already started".
brew services start postgresql@17

# Verify the server answers before returning OK.
export PATH="/opt/homebrew/opt/postgresql@17/bin:${PATH}"
for _ in $(seq 1 15); do
    if pg_isready -q >/dev/null 2>&1; then
        echo "ok:postgresql@17 ($(pg_isready 2>/dev/null))"
        exit 0
    fi
    sleep 1
done
echo "warn:postgresql@17 (service started but server not answering on :5432 yet)"
