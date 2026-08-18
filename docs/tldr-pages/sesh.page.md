# sesh

> Create and select tmux sessions from repositories, zoxide paths, and live sessions.
> The local tmux configuration opens the picker with `prefix + S`.
> More information: <https://github.com/joshmedeski/sesh>.

- Open the configured interactive session picker:

`sesh picker -idHs`

- List known sessions and directories:

`sesh list`

- Connect to a selected session:

`sesh connect {{session}}`

- Connect to the last tmux session:

`sesh last`

- Clone a repository and connect to its session:

`sesh clone {{repository_url}}`

- Rename the current session:

`sesh rename {{name}}`
