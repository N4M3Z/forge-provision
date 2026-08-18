# zed

> Open files and projects in Zed.
> The local setup uses Zed as a launcher for terminal tools and agent threads.
> Leader keys apply in Vim normal or visual mode.
> More information: <https://zed.dev/docs/cli>.

- Open a project in the running Zed channel:

`zed {{path/to/project}}`

- Open a file at a line and column:

`zed {{path/to/file}}:{{line}}:{{column}}`

- Open the native task picker for every configured tool:

`space .`

- Start or attach the project's terminal thread:

`space a n`

- Review the current file in tuicr:

`space r f`

- Review the working tree in tuicr:

`space r w`

- Open a path in the running Zed bundle, including Zed Dev:

`sd zed open {{path/to/file}}`

- Build the personal Zed patch stack without installation:

`sd zed rebuild`
