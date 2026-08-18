# rtk

> Compress command output before it enters an AI agent context.
> The local setup initializes Claude Code hooks and Codex instructions.
> More information: <https://github.com/rtk-ai/rtk>.

- Initialize global Claude Code integration:

`rtk init -g`

- Initialize global Codex instructions:

`rtk init -g --codex`

- Run a Git command with compact output:

`rtk git {{arguments}}`

- Run tests and show failures only:

`rtk test {{test_command}}`

- Run a command and show errors or warnings only:

`rtk err {{command}}`

- Show token savings:

`rtk gain`

- Verify hook integrity and custom filters:

`rtk verify`
