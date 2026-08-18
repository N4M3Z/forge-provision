# codex

> Run OpenAI Codex as an independent coding agent and cross-reviewer.
> The local configuration includes workspace isolation and a read-only review profile.
> More information: <https://developers.openai.com/codex/cli/>.

- Start an interactive session:

`codex`

- Authenticate interactively:

`codex login`

- Review changes with the local read-only profile:

`codex --profile review {{prompt}}`

- Run the built-in headless review command:

`codex exec review`

- Validate configuration and effective policy:

`codex doctor`

- List configured MCP servers:

`codex mcp list`

- Run Codex through shared provider policy explicitly:

`sd agent run codex {{arguments}}`
