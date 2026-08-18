# gbrain

> Manage a local knowledge brain with Markdown, PostgreSQL, pgvector, and embeddings.
> Use `memex` for the preconfigured personal database.
> More information: <https://github.com/garrytan/gbrain>.

- Check the brain configuration and dependencies:

`gbrain doctor`

- Capture text into the inbox:

`gbrain capture {{text}}`

- Ask a question with hybrid search:

`gbrain query {{question}}`

- Find pages with keyword search:

`gbrain search {{query}}`

- Import a Markdown directory without embeddings:

`gbrain import {{path/to/directory}} --no-embed`

- Synchronize a Git repository into the brain:

`gbrain sync --repo {{path/to/repository}}`

- Refresh stale embeddings:

`gbrain embed --stale`

- Start the MCP server:

`gbrain serve`
