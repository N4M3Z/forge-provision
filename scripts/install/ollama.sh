#!/bin/bash
# Install the Ollama desktop app and start its menu-bar server.
# Idempotent: skips the install when Ollama.app is present; opening an
# already-running app is a no-op.
#
# Ollama is the local model-inference tier: it serves embedding and chat models
# on localhost:11434 with no API key, so tools (a personal knowledge brain, RAG
# pipelines, an editor's inline assist) can embed and query fully offline. The
# desktop app runs the server from the menu bar and provides the `ollama` CLI.
# Enable "Open at Login" in the app so the server is up headless after a reboot.
# Pulling specific models with `ollama pull <model>` is application setup, not
# base provisioning, so it is intentionally left out of this script.
#
# Gotcha: the public registry (registry.ollama.ai) is Cloudflare-fronted and the
# daemon does not fall back from a dead IPv6 route, so `ollama pull` can time out
# on some networks even though plain HTTPS reaches the host. Workaround: download
# a GGUF from a reachable source and side-load it via a Modelfile + `ollama
# create <name> -f Modelfile`.
#
# Reference: https://ollama.com
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if [ -d "/Applications/Ollama.app" ]; then
    echo "skip:ollama-app (already installed)"
else
    echo "install:ollama-app"
    brew install --cask ollama-app
fi

echo "start:ollama-app"
# The app runs the server from the menu bar; opening it (idempotent) starts the
# daemon on :11434.
open -a Ollama

# Verify the daemon answers before returning OK.
for _ in $(seq 1 20); do
    if curl -fsS http://localhost:11434/api/version >/dev/null 2>&1; then
        echo "ok:ollama ($(curl -fsS http://localhost:11434/api/version))"
        exit 0
    fi
    sleep 1
done
echo "warn:ollama (app launched but daemon not answering on :11434 yet)"
