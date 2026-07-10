---
title: pxpipe image-compression proxy
description: Claude Code routes through pxpipe, a pinned, localhost-only proxy that renders static request context (system prompt, tool docs, collapsed history) as PNGs to exploit image-token pricing, cutting Fable token usage substantially. Wiring is fail-open via the claude() shell wrapper, so sessions never depend on the proxy. Imaged content is not byte-exact; non-allowlisted models pass through unchanged.
type: adr
category: tooling
tags:
    - pxpipe
    - claude-code
    - tokens
    - proxy
    - cost
status: accepted
created: 2026-07-05
updated: 2026-07-05
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0004 JavaScript runtime bun.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# pxpipe image-compression proxy

## Context and Problem Statement

Claude Code requests carry a large static slab, system prompt, tool documentation, collapsed history, that is re-sent with every call and dominates token counts (a trivial headless run here carried a 156k-character slab, ~109k tokens). Text costs roughly one token per character; images cost by pixel dimensions, and dense text packs ~3.1 characters per image token. pxpipe exploits that asymmetry: a localhost proxy that intercepts `/v1/messages` and re-renders the static slab as PNGs before forwarding upstream, with 59-70% total-bill cuts reported. On a subscription, the saving appears as usage-window headroom. The question is whether inserting a third-party process into the model API path is worth that headroom, and under what constraints.

## Decision Drivers

- Usage-window headroom on a flat-rate subscription; heavy parallel-agent use hits caps.
- The primary model here reads the renders reliably; others do not.
- Nothing in the model path may become a hard dependency or an unreviewed moving part.
- Byte-exact fidelity matters selectively (identifiers, hashes), not universally.

## Considered Options

1. **Adopt, pinned and fail-open.** Version-pinned global install; a shell-wrapper sets `ANTHROPIC_BASE_URL` only while the proxy port answers.
2. **Adopt always-on** via `settings.json` env. Every session hard-depends on the proxy process; a dead proxy breaks all sessions.
3. **Skip.** Keep paying full text pricing for the static slab.

## Decision Outcome

Chosen option: **option 1**.

- **Pinned install** (`bun install -g pxpipe-proxy@<version>`, never bare `npx`): the proxy reads every request, so the running version must be the reviewed version; bumps are deliberate.
- **Fail-open wiring**: the `claude()` wrapper auto-starts the proxy and routes through it only when the port answers; otherwise sessions use the direct API silently. Availability of the proxy is never availability of Claude.
- **Scope**: compression applies only to allowlisted models (`PXPIPE_MODELS`, default Fable 5 and GPT 5.6, both ~100% render-read accuracy; Opus misreads ~7% and stays opt-in). Everything else, and all model responses, pass through byte-identical.
- Verified locally before adoption: subscription OAuth passes through; the `[1m]` model alias resolves to the allowlisted wire id; a real request imaged its slab into 6 PNGs; a non-allowlisted model passed through untouched.

### Consequences

- [+] Substantial token headroom on the models that matter here, with zero workflow change.
- [+] Local-only: upstreams are the official APIs, the dashboard and event log stay on 127.0.0.1.
- [-] Imaged content is not byte-exact (visual re-reading loses occasional characters). Coding tolerates this, since files are re-read before edits, but byte-critical pipelines must use a non-allowlisted model or stop the proxy.
- [-] A third-party process sits in the model path and sees every request; the pin plus deliberate review-and-bump is the mitigation, and the `~/.pxpipe/` event log and proxy log join the telemetry stores needing retention discipline.
- [-] Sessions started outside the wrapper (desktop app, IDE-spawned) bypass the proxy and pay full price; acceptable for a terminal-first workflow.

## Links

- [pxpipe](https://github.com/teamchong/pxpipe)
- [pxpipe tldr](../tldr/pxpipe.md)
