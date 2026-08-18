# dcg

> Block destructive shell commands before supported coding agents execute them.
> The local setup installs hooks for Claude Code and Codex.
> More information: <https://github.com/Dicklesworthstone/destructive_command_guard>.

- Check hook installation and configuration:

`dcg doctor`

- Test a command against enabled policy packs:

`dcg test {{command}}`

- Explain why a command is allowed or blocked:

`dcg explain {{command}}`

- List all policy packs and their state:

`dcg packs`

- Show the effective configuration:

`dcg config`

- Scan files for destructive commands:

`dcg scan {{path}}`
