# agy

> Run the Antigravity terminal coding agent.
> The local wrapper enables its terminal sandbox and shared session capture.
> More information: <https://antigravity.google/product/antigravity-cli>.

- Start an interactive sandboxed session:

`agy`

- Continue the latest session:

`agy --continue`

- Run one prompt and exit:

`agy -p {{prompt}}`

- Test authentication:

`agy -p "reply with the word READY"`

- Check MCP server visibility:

`agy -p "list your MCP servers"`

- Run Antigravity through shared provider policy explicitly:

`sd agent run antigravity {{arguments}}`
