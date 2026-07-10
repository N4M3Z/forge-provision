---
title: Local MLX inference lane (oMLX) alongside Ollama
description: oMLX joins Ollama as a second local inference server — an Apache-2.0 MLX runtime on localhost:8000, OpenAI-compatible, serving MLX-format models from ~/.omlx/models with a tiered RAM+SSD KV cache. Installed from the macOS .dmg (the native menu-bar app) via a script that resolves the OS-matched asset from the releases API; the Homebrew formula is the headless alternative, and both share the port and state, so one server runs at a time. The inline-assist model is Qwen3-Coder-Next, a non-thinking MoE. Config splits public/private like PROV-0020.
type: adr
category: tooling
tags:
    - mlx
    - omlx
    - ollama
    - inference
    - apple-silicon
    - zed
status: accepted
created: 2026-07-01
updated: 2026-07-10
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0020 Zed editor-as-launcher and REPL kernels.md"
    - "PROV-0018 Zed markdown and PKM capability boundary.md"
    - "PROV-0005 Secret scanning.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Local MLX inference lane (oMLX) alongside Ollama

## Context and Problem Statement

The machine already runs Ollama as the local inference tier: a GGUF runtime (llama.cpp) on `localhost:11434` serving the embedding model for the knowledge brain and a small coder for Zed's Inline Assist. On Apple Silicon the GGUF path leaves speed on the table — MLX decodes faster than llama.cpp, markedly so for mixture-of-experts models where only a few billion parameters are active per token, and uses less memory. MLX's weakness is prefill and long-context, which is where oMLX's differentiator lands: a tiered RAM+SSD KV cache that persists and reuses context across requests, plus continuous batching.

The open questions: whether to add an MLX lane at all given Ollama already covers local inference, which server to run, which model to serve for clean inline edits, and how to keep the setup reproducible without leaking personal configuration into a public repo.

## Decision Drivers

- Faster local inline-assist and agent inference on Apple Silicon, especially for MoE coders.
- Preserve the OpenAI-compatible contract so editors and tools point at the endpoint unchanged.
- Coexist with the existing GGUF runner rather than replace it.
- Reproducible install; the API key and any personal endpoints stay private.
- The inline model must apply surgical edits without leaking reasoning traces into the buffer — Zed's Inline Assist mishandles `<think>` output.

## Decision Outcome

- **Add oMLX (Apache-2.0) as a second local lane** on `localhost:8000`, OpenAI-compatible, serving MLX models discovered from `~/.omlx/models`. Its port is clear of Ollama (`11434`) and LM Studio (`1234`), so all three coexist and are selected per task.
- **Install the `.dmg` menu-bar app**, scriptable in `scripts/install/omlx.sh`. The DMG asset name embeds the release version and the macOS major (`macos15-sequoia` vs `macos26-27`), so there is no stable canonical-latest URL: the script resolves the download from the GitHub releases API by matching the running macOS, copies `oMLX.app` to `/Applications`, and symlinks the bundled `omlx-cli` to `~/.local/bin/omlx`. The Homebrew formula (tap → `brew trust` → install → `brew services`) is the headless alternative — the formula and app declare no conflict and can both be installed, but both bind `:8000` and share `~/.omlx/`, so exactly one server runs at a time, and the `omlx` CLI on `PATH` is ambiguous when both are present.
- **Model: Qwen3-Coder-Next** — a non-thinking MoE (~3B active of 80B, ~44.8GB at 4-bit, ~50 tok/s warm on an M5 Max) that is fast on unified memory, coder-tuned, and returns clean `content` with no reasoning trace. Zed publishes no inline-assist model recommendation (its only opinion is the Zeta edit-prediction model); this pick matches the community consensus and Zed's own local-models guidance, which favours a non-thinking MoE coder on unified memory. A reasoning model was ruled out after `gpt-oss-20b` returned `reasoning_content` that Inline Assist mishandles.
- **Wire into Zed as an `openai_compatible` provider**; oMLX/Qwen3-Coder-Next is the inline-assist model, with Ollama's GGUF coder kept as the baseline reference. The generic `openai_compatible` block ships in `manifests/zed/settings.jsonc`; the API key lives in Zed's keychain via the provider UI, never in tracked settings. Zed's `capabilities` object is all-or-nothing — a partial one (`{ "tools": true }`) rejects the whole settings file.
- **Public/private split mirrors PROV-0020.** forge-provision carries the install script, the Brewfile pointer, and the generic Zed provider block; the dotfiles lane carries the key and any personal endpoints.
- **Out of scope: GLM 5.2.** A ~744B MoE whose smallest usable quant is ~217GB, it exceeds a 128GB Apple Silicon machine (and a 128GB desktop even with a 24GB GPU offloading), so it is API-only at this hardware tier. A ~256GB unified-memory box is the local floor. GLM-4.x-Air (~106B) is the local-GLM option that fits.

### Consequences

- [+] MLX decode speed for MoE coders on Apple Silicon, and the SSD KV cache targets the long-context/repeated-prefix work where MLX is otherwise weak.
- [+] Additive, not a migration: Ollama, oMLX, and LM Studio run on distinct ports and are chosen per task; the OpenAI contract keeps editor config backend-agnostic.
- [+] The `.dmg` install is reproducible from a fresh machine; the script resolves the OS-matched asset from the releases API, so it tracks upstream without a pinned URL.
- [-] oMLX and Ollama overlap in role, so there are two local runtimes to keep patched and two model stores to manage.
- [-] The app and the optional formula share `:8000` and `~/.omlx/` — a one-server-at-a-time constraint and an ambiguous CLI when both are installed.
- [-] MLX weights are a separate download from the GGUF ones with no shared cache, and only MLX-format models load — GGUF from the Ollama/LM Studio side is not reusable here.

## Links

- [PROV-0020 Zed editor-as-launcher and REPL kernels](PROV-0020%20Zed%20editor-as-launcher%20and%20REPL%20kernels.md) — the public/private config split this reuses
- [PROV-0018 Zed markdown and PKM capability boundary](PROV-0018%20Zed%20markdown%20and%20PKM%20capability%20boundary.md)
- [PROV-0005 Secret scanning](PROV-0005%20Secret%20scanning.md) — the local LM Studio OpenAI endpoint and the `~/.env` API-key precedent
- [oMLX](https://github.com/jundot/omlx) · [MLX](https://github.com/ml-explore/mlx) · [Qwen3-Coder-30B-A3B-Instruct](https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct)
