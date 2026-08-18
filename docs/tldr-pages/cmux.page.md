# cmux

> Manage terminal workspaces, surfaces, and agent sessions in cmux.
> The local setup adds Claude hooks and crex snapshots.
> More information: <https://cmux.com/docs>.

- Open cmux:

`cmux`

- Configure Claude Code lifecycle hooks:

`cmux hooks setup`

- Pin an exact Claude resume command to the active surface:

`cmux surface resume set "claude --resume {{session_id}}"`

- Show the resume command for the active surface:

`cmux surface resume show`

- Launch Claude with agent teams as visible splits:

`cmux claude-teams {{claude_arguments}}`

- Save the current workspace layout with crex:

`crex save {{layout_name}}`

- Restore a named workspace layout with crex:

`crex restore {{layout_name}}`

- Open the searchable agent-session vault:

`cmux right-sidebar vault`
