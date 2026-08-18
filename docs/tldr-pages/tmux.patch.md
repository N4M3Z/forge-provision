- Resolve the local project session name:

`sd tmux session-name`

- List stable session identifiers with readable names:

`tmux list-sessions -F '#{session_id} #{session_name}'`

- Attach by stable identifier when a session name contains `.` or `:`:

`tmux attach-session -t '{{session_id}}'`

- Open the local command menu from an attached client:

`prefix + ?`

- Reload the complete local configuration:

`tmux source-file ~/.config/tmux/tmux.conf`
