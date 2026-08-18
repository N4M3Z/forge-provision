# claude

> Start Claude Code with the local policy, proxy, attribution, and capture wrappers.
> Resume from the same working directory because native sessions use directory keys.
> More information: <https://code.claude.com/docs/en/cli-reference>.

- Start an interactive session:

`claude`

- Continue the latest session for the current directory:

`claude --continue`

- Select a previous session:

`claude --resume`

- Resume an exact session:

`claude --resume {{session_id}}`

- Run one non-interactive prompt:

`claude --print {{prompt}}`

- Resume the exact pane session through the local breadcrumb wrapper:

`sd claude resume`

- Run Claude through shared provider policy explicitly:

`sd agent run claude {{arguments}}`
