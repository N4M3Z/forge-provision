#!/bin/bash
# Install Ollama and start it as a background service.
# Idempotent: skips the brew install if `ollama` is on PATH; the service start
# is safe to re-run (an already-running service is left as-is).
#
# Ollama is the local model-inference tier: it serves embedding and chat models
# on localhost with no API key, so tools (a personal knowledge brain, RAG
# pipelines) can embed and query fully offline. Pulling specific models with
# `ollama pull <model>` is application setup, not base provisioning, so it is
# intentionally left out of this script.
#
# Gotcha: the public registry (registry.ollama.ai) is Cloudflare-fronted and the
# daemon does not fall back from a dead IPv6 route, so `ollama pull` can time out
# on some networks even though plain HTTPS reaches the host. Workaround: download
# a GGUF from a reachable source and side-load it via a Modelfile + `ollama
# create <name> -f Modelfile`.
#
# Reference: https://github.com/ollama/ollama
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if command -v ollama >/dev/null 2>&1; then
    echo "skip:ollama (already installed: $(command -v ollama))"
else
    echo "install:ollama"
    brew install ollama
fi

echo "start:ollama-service"
# Run as a launchd service so it restarts at login. `brew services start` is
# idempotent: an already-running service reports "already started".
brew services start ollama

# Verify the daemon answers before returning OK.
for _ in $(seq 1 15); do
    if curl -fsS http://localhost:11434/api/version >/dev/null 2>&1; then
        echo "ok:ollama ($(curl -fsS http://localhost:11434/api/version))"
        exit 0
    fi
    sleep 1
done
echo "warn:ollama (service started but daemon not answering on :11434 yet)"
