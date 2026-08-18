# memex

> Run gbrain against the local `memex` PostgreSQL database.
> The wrapper also limits embedding concurrency for the local model server.

- Capture text into the local brain:

`memex capture {{text}}`

- Capture standard input into the local brain:

`{{command}} | memex capture --stdin`

- Recall relevant pages with hybrid search:

`memex query {{question}}`

- Search page text by keyword:

`memex search {{query}}`

- Synchronize the current repository:

`memex sync --repo {{path/to/repository}}`

- Check the local brain and model connections:

`memex doctor`
