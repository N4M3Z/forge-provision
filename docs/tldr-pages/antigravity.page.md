# antigravity

> Run Google's Antigravity coding agent through its `agy` command.
> The local setup shares MCP configuration with the Antigravity desktop application.
> More information: <https://antigravity.google/product/antigravity-cli>.

- Start an interactive sandboxed session:

`agy`

- Continue the latest session:

`agy --continue`

- Run one prompt and exit:

`agy -p {{prompt}}`

- Test local MCP server visibility:

`agy -p "list your MCP servers"`

- Run through shared provider policy and session capture:

`sd agent run antigravity {{arguments}}`
