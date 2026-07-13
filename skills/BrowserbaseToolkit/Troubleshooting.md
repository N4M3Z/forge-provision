# Troubleshooting

Symptom-first fixes for Browserbase failures whose error messages point at the wrong culprit. The upstream [`Reference.md`](Reference.md) covers CLI mechanics (missing key, unknown flag); this covers the traps where the message lies.

| Symptom | Actual cause | Fix |
| --- | --- | --- |
| "API key not valid" / "Incorrect API key provided" from an LLM call, while the browser session itself started fine | A placeholder provider key in `.env` (`MODEL_API_KEY=your_api_key_here`) is overriding Model Gateway, so Stagehand sends the placeholder to the provider | Blank every provider key so LLM calls route through the Browserbase key (snippet below) |
| LLM calls start failing on a script that worked before; sessions still start | The Free plan's Model Gateway token allowance ($5) is exhausted, and the cap is not surfaced up front | Bring your own LLM key, go deterministic (below), or upgrade. Say "the free token allowance is used up", not "the plan is broken" |
| Session starts but the target site blocks, loops a CAPTCHA, or never loads | Bot-protected or auth-walled target (LinkedIn, Instagram, Facebook, TikTok, Yelp, ticketing, most large retailers); Proxies and Verified are paid features. The response usually names the wall: HTTP 403 with `X-Datadome: protected`, or Cloudflare challenge markup | Reroute to a source that answers the same question via Fetch / Search or an unprotected site; suggest upgrading only if the protected site is genuinely required |
| `browse cloud fetch` returns a 301/302 and stops | Fetch does not follow redirects by default | Pass `--allow-redirects` |
| Setup stalls asking for `BROWSERBASE_PROJECT_ID` | Outdated docs and training data; the API key alone resolves the project | Never set it, never pass `projectId`; leave the var blank if a template ships it |

## Template `.env` hygiene

Set the real key, blank every placeholder, in one pass (BSD-sed safe; this is the exact sequence that makes the starter templates run on the Browserbase key alone):

```sh
sed -i.bak "s|^BROWSERBASE_API_KEY=.*|BROWSERBASE_API_KEY=$BROWSERBASE_API_KEY|" .env
for V in MODEL_API_KEY OPENAI_API_KEY GOOGLE_API_KEY ANTHROPIC_API_KEY AZURE_API_KEY AZURE_ENDPOINT BROWSERBASE_PROJECT_ID; do
    sed -i.bak "s|^$V=.*|$V=|" .env
done
rm -f .env.bak
```

## Past the token cap: two real exits

- **Bring your own LLM key.** Export the provider key (e.g. `ANTHROPIC_API_KEY`) and set Stagehand's `model` to that provider's model. The cloud browser stays on Browserbase; inference bills to your provider.
- **Go deterministic.** Rewrite the `act` / `extract` steps as plain Playwright over the same Browserbase session (connect over CDP). Zero LLM tokens, works on Free, more brittle when the page changes.

## Escalation order for a blocked site

Cheapest first: `browse cloud fetch <url>` (no browser, no tokens), then `browse cloud search "<query>"` for an alternative source, then a plain session on an unprotected mirror of the data, and only then Proxies / Verified on a paid plan.
