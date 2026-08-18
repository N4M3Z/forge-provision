# cliproxyapi

> Serve one local OpenAI-compatible endpoint for several model-provider subscriptions.
> The local setup uses a Homebrew service and a protected management interface.
> More information: <https://github.com/router-for-me/CLIProxyAPI>.

- Start the terminal management interface with an embedded server:

`cliproxyapi -tui -standalone`

- Use an explicit configuration file:

`cliproxyapi -config {{path/to/config.yaml}}`

- Authenticate a Claude subscription:

`cliproxyapi -claude-login`

- Authenticate a Codex subscription:

`cliproxyapi -codex-login`

- Authenticate an Antigravity subscription:

`cliproxyapi -antigravity-login`

- Authenticate an xAI subscription:

`cliproxyapi -xai-login`
