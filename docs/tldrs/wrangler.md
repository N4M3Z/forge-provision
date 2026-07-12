# wrangler

Cloudflare's CLI (v4): Workers, Pages, KV, R2, D1 from the terminal. Installed as `cloudflare-wrangler` via Brewfile; the binary is `wrangler`. Auth check: `scripts/configure/cloudflare.sh`.

## Auth

| Command | What it does |
|---|---|
| `wrangler login` | Browser OAuth; session stored under `~/Library/Preferences/.wrangler/` |
| `wrangler whoami` | Show account + token scopes (exits 0 even when unauthenticated) |
| `wrangler logout` | Drop the OAuth session |
| `CLOUDFLARE_API_TOKEN=...` | Headless auth; overrides the OAuth session. Keep the token in `pass cloudflare/api-token` |
| `--profile <name>` | Switch between auth profiles (work vs personal accounts) |

## Workers lifecycle

| Command | What it does |
|---|---|
| `wrangler init [name]` | Scaffold a Worker project |
| `wrangler dev` | Local dev server for the Worker in cwd |
| `wrangler deploy` | Deploy the Worker (config from `wrangler.toml` / `wrangler.jsonc`) |
| `wrangler deploy --temporary` | Deploy without logging in, onto a temporary preview account |
| `wrangler tail [worker]` | Live log stream from a deployed Worker |
| `wrangler versions` | List / upload / deploy Worker versions |
| `wrangler rollback [version-id]` | Roll a deployment back |
| `wrangler secret` | Manage Worker secrets |
| `wrangler types` | Generate TypeScript types from the Worker config |
| `wrangler delete [name]` | Remove a Worker |

## Storage and platform

| Command | What it does |
|---|---|
| `wrangler kv` | Workers KV namespaces |
| `wrangler r2` | R2 buckets and objects |
| `wrangler d1` | D1 (SQLite) databases |
| `wrangler queues` | Workers Queues |
| `wrangler pages` | Cloudflare Pages projects |
| `wrangler containers` | Cloudflare Containers |
| `wrangler hyperdrive` | Hyperdrive database acceleration |
| `wrangler vectorize` | Vectorize vector indexes |

## Global flags

| Flag | What it does |
|---|---|
| `-c, --config <path>` | Explicit Wrangler config file |
| `-e, --env <name>` | Select environment (also picks `.env` / `.dev.vars` variants) |
| `--env-file <path>` | Load extra `.env` files (repeatable; later wins) |
| `--cwd <dir>` | Run as if started in another directory |
| `--install-skills` | Install Cloudflare skills for detected AI coding agents |
