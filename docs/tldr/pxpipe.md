# pxpipe

A localhost proxy ([teamchong/pxpipe][REPO], MIT) between Claude Code and `api.anthropic.com` that renders the bulky static parts of each request, system prompt, tool docs, collapsed history, large tool results, as PNGs. Image tokens price by pixels, not characters (~3.1 chars per token for dense text), so the same context costs a fraction: 59-70% cuts reported upstream; on a Max subscription the saving is usage-window headroom, not dollars. The decision and risk analysis live in [PROV-0022][ADR].

## Install and wiring

```sh
./scripts/install/pxpipe.sh      # pinned bun global install (never bare npx)
```

Runtime wiring is the `claude()` wrapper in the dotfiles zshrc: it auto-starts the proxy when idle and sets `ANTHROPIC_BASE_URL=http://127.0.0.1:47821` only while the port answers, so **sessions fall back to the direct API silently** when the proxy is down. Manual one-off: `ANTHROPIC_BASE_URL=http://127.0.0.1:47821 claude`.

## What it does and doesn't touch

| | |
| --- | --- |
| Compressed | requests only, and only the static slab (system prompt, tool docs, old history, tool results over ~6k chars) |
| Never touched | model responses; any non-allowlisted model (passes through byte-identical) |
| Model allowlist | `PXPIPE_MODELS`, default `claude-fable-5,gpt-5.6`; Opus 4.7/4.8 misread ~7% and stay opt-in |
| Verified here | subscription OAuth passes through; `claude-fable-5[1m]` resolves to the allowlisted wire id; a `-p` run imaged a 156k-char slab into 6 PNGs; haiku passed through as `unsupported_model` |
| Dashboard | `http://127.0.0.1:47821/` (live savings, model toggles) |

## Unwire

Built to be removed in seconds if the pricing asymmetry gets closed or the technique frowned upon; nothing else depends on it.

```sh
export PXPIPE_DISABLE=1          # this shell: wrapper skips the proxy entirely
bun remove -g pxpipe-proxy       # permanent: wrapper self-disables (command -v gate)
```

Sessions fall back to the direct API either way; no config cleanup needed. Full removal on top: delete `~/.pxpipe/` and drop the wrapper block from the zshrc.

## Caveats

- **Lossy for byte-exact strings.** Imaged content is read visually (13/15 hex recall on Fable): fine for coding (the agent re-reads files before editing), wrong for pipelines needing verbatim recall of IDs/hashes/secrets. Escape hatch: non-allowlisted models pass through as text.
- **`~/.pxpipe/events.jsonl` is a content-adjacent store** (hashes, sizes, model, paths, not full bodies) and `proxy.log` grows; both need the same retention discipline as the OTEL telemetry dir.
- **Supply chain**: the proxy sees every request. The install pins `pxpipe-proxy@<version>`; bump deliberately, never `npx` latest.
- **Complementary to rtk**, not overlapping: rtk compacts tool *output* as text before it enters context; pxpipe images the request on the wire. Synergy detail: pxpipe images tool_results over ~6k chars in **all** turns (`minToolResultChars`, per its transform source, despite the README's recent-turns wording), and dense text with identifiers is its weakest read class, but rtk's compaction keeps most tool outputs *under* that threshold, so rtk shrinks exactly the input pxpipe handles worst. There is no per-tool_result opt-out (documented in the README, not a tracked issue); the only lever is the model allowlist. The commercial [Headroom](https://github.com/headroomlabs-ai/headroom) bundles rtk but compresses text semantically (AST/JSON) with reversible retrieval, not pxpipe's text-as-image; its CacheAligner is the piece worth borrowing.
- **Prompt caching**: pxpipe claims cache safety (it relocates `cache_control` onto the imaged prefix and tracks `cache_read_tokens` per event); vendor-tested, not independently confirmed. If dashboard `cache_read` craters during real sessions, that's the signal to investigate.

[REPO]: https://github.com/teamchong/pxpipe "pxpipe"
[ADR]: ../decisions/PROV-0022%20pxpipe%20image-compression%20proxy.md "PROV-0022"
