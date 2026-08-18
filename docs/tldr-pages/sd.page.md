# sd

> Run personal dispatch commands from the chezmoi-managed `sd` command tree.
> Subcommands cover agents, Zed, tmux, GitHub, and local tldr pages.

- List available dispatch commands:

`sd`

- Show local and upstream tldr pages:

`sd tldr`

- Open a path in the currently running Zed bundle:

`sd zed open {{path/to/file}}`

- Build the personal Zed patch stack:

`sd zed rebuild`

- Resolve the canonical tmux session name for the current directory:

`sd tmux session-name`

- Resume the exact Claude session for the current pane:

`sd claude resume`

- Show the exact Claude resume command for the current pane:

`sd claude resume --print`

- Run an agent through shared policy and capture:

`sd agent run {{claude|codex|antigravity|grok|opencode}} {{arguments}}`
