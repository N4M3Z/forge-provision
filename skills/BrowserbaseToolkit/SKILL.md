---
name: BrowserbaseToolkit
version: 0.1.0
description: "Drive real Chrome browsers in the cloud with Browserbase and the browse CLI: automate, scrape, fill forms, and run browser agents (Stagehand), plus Fetch, Search, Sessions, Contexts, and Functions. USE WHEN automating or scraping a website, driving a headless/cloud browser, using Browserbase or the browse CLI or Stagehand, fetching a page's content, web search for URLs, filling a web form programmatically, or deciding which browser-automation capability to use."
sources:
    - https://browserbase.com/SKILL.md
    - https://docs.browserbase.com
---

# BrowserbaseToolkit

Browserbase runs real Chrome browsers in the cloud that code (or an agent) drives, so you automate and scrape the web without a browser on the machine. The `browse` CLI is the entry point; Stagehand drives the browser with natural language instead of brittle selectors.

The full command reference is the adopted upstream skill (source of truth): [`Reference.md`](Reference.md), pinned with provenance in `.provenance/Reference.yaml` (upstream: `https://browserbase.com/SKILL.md`). This file carries setup and capability selection; when a run fails with a misleading error, go straight to [`Troubleshooting.md`](Troubleshooting.md).

## Setup

```sh
npm install -g browse@latest          # the browse CLI (needs Node)
export BROWSERBASE_API_KEY=bb_live_<your-key>   # the ONLY secret needed
browse cloud projects list            # verify access
```

The API key alone identifies the project. **Never set `BROWSERBASE_PROJECT_ID`** and never pass a `projectId` to an SDK; older docs that say it is required are out of date. The key resolves the project for the CLI and every SDK (Stagehand, `@browserbasehq/sdk`, Playwright-over-CDP).

## Choosing a capability

Pick the lightest one that fits, then read its doc + SDK README before integrating.

| Capability | Use it when |
| --- | --- |
| Fetch | You just need a page's content, no JS or interaction. Fastest, no browser. |
| Search | You need URLs / web results for a query, no browsing. |
| Stagehand | Natural-language automation (`act` / `extract` / `observe` / `agent`). Best default for agentic browsing and extraction. |
| Sessions (Playwright / Puppeteer / Selenium) | The project already uses one, or you need deterministic scripted control over CDP. |
| Contexts | Persistent login / cookies reused across runs. |
| Functions | Run the automation in Browserbase's cloud on a schedule or webhook (TypeScript only). |
| Proxies / Verified | Bot-protected, geo-restricted, or CAPTCHA sites (paid). |
| Model Gateway | Call LLMs through the Browserbase key, one key, one bill. |

Rule of thumb: Fetch/Search when no full browser is needed, Stagehand for agentic browsing, Playwright/Puppeteer/Selenium if the project already uses them. Stagehand reads `BROWSERBASE_API_KEY` from the env and needs `env: "BROWSERBASE"`; leave provider keys unset so LLM calls route through Model Gateway.

## Templates and skills

- `browse templates list` / `browse templates clone <slug> <dir> --language typescript` for runnable starters (`amazon-product-scraping`, `form-filling`, `sec-filing-research`).
- `browse skills find "<task>" --json` searches browse.sh, a catalog of tested per-site automations; `browse skills add <domain>/<task>` installs one.

## Verify

```sh
browse cloud sessions list   # a browser run shows up here (RUNNING/COMPLETED)
```

Full session replay: `https://www.browserbase.com/sessions/<full-id>` (never truncate the id). Fetch and Search do not spin up a browser session, so for those, success is a results payload, not a session row.

## When it fails with a lying error

"API key not valid" mid-run, a script that stops working overnight, a site that never loads: the message usually blames the wrong thing (a placeholder key, the free token cap, bot protection). [`Troubleshooting.md`](Troubleshooting.md) maps each symptom to its actual cause and a runnable fix.
