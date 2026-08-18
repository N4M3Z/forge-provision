- Verify the active Cloudflare account and token scopes:

`wrangler whoami`

- Deploy to an unauthenticated temporary preview account:

`wrangler deploy --temporary`

- Select a configured work or personal authentication profile:

`wrangler --profile {{profile}} {{command}}`

- Read a headless API token from pass for one command:

`CLOUDFLARE_API_TOKEN="$(pass cloudflare/api-token)" wrangler {{command}}`
