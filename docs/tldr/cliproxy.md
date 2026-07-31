# CLIProxyAPI

One local HTTP endpoint that re-exposes the CLI provider subscriptions (Claude, Codex, Antigravity, xAI, Kimi) as OpenAI-, Anthropic-, and Gemini-compatible APIs. The proxy holds the provider OAuth logins, so each harness authenticates to it with a single local key instead of carrying its own provider credentials. Runedeck is not involved; this is the plain binary plus its config file.

## Install and prepare

```sh
brew install cliproxyapi            # declared in manifests/Brewfile and Brewfile.work
./scripts/configure/cliproxy.sh     # loopback binding, api key, service
```

The configure script pins `host` to `127.0.0.1`, leaves `remote-management` disabled, and sets a single api key, preferring an existing one, then Proton Pass, then a generated one. It is idempotent.

## Paths

| Path                                 | Role                                              |
| ------------------------------------ | ------------------------------------------------- |
| `/opt/homebrew/etc/cliproxyapi.conf` | Config. Path is compiled in; `-config` overrides. |
| `~/.cli-proxy-api/`                  | Provider OAuth tokens, written by the logins.     |
| `127.0.0.1:8317`                     | Listening address after the configure script.     |

Read the api key back without printing it into a shared context:

```sh
yq -r '.api-keys[0]' /opt/homebrew/etc/cliproxyapi.conf
```

## Bring it up

`brew services` refuses to run under tmux, because launchctl would target tmux's bootstrap namespace rather than the login session. Start it from a shell outside tmux:

```sh
brew services start cliproxyapi
brew services list | grep cliproxyapi
```

Then log in once per provider. Each opens a browser; add `-no-browser` for a paste-the-URL flow. There is no `-gemini-login`: Antigravity is the Google path.

```sh
cliproxyapi -claude-login
cliproxyapi -codex-login        # or -codex-device-login
cliproxyapi -antigravity-login
cliproxyapi -xai-login
```

## Endpoints

Confirmed against the running server. A `GET` on a POST-only route returns 404, so absence of a route cannot be inferred from a GET.

| Endpoint                                        | Shape             | Client                |
| ----------------------------------------------- | ----------------- | --------------------- |
| `POST /v1/messages`                             | Anthropic         | Claude Code           |
| `POST /v1/responses`                            | OpenAI Responses  | Codex                 |
| `POST /v1/chat/completions`                     | OpenAI chat       | opencode and similar  |
| `POST /v1beta/models/<model>:generateContent`   | Gemini            | Gemini-compatible     |
| `GET /v1/models`, `GET /v1beta/models`          | Model listings    | Discovery             |

The key is accepted as either `Authorization: Bearer <key>` or `x-api-key: <key>`. With no provider logged in, a request returns 502 `unknown provider for model <name>`, which confirms routing and auth while naming the missing piece.

## Point the harnesses at it

### Claude Code

`apiKeyHelper` is a top-level setting whose output is sent as both `X-Api-Key` and `Authorization: Bearer`, so the key is read at runtime and never written into a settings file.

```json
{
    "env": {
        "ANTHROPIC_BASE_URL": "http://127.0.0.1:8317"
    },
    "apiKeyHelper": "yq -r '.api-keys[0]' /opt/homebrew/etc/cliproxyapi.conf"
}
```

`ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_API_KEY` also work in the `env` block, but both put the key in the file.

### Codex

Keys below are validated by `codex --strict-config`, which errors on fields this version does not recognize.

```toml
model_provider = "cliproxy"

[model_providers.cliproxy]
name = "CLIProxyAPI"
base_url = "http://127.0.0.1:8317/v1"
env_key = "CLIPROXY_API_KEY"
wire_api = "responses"
```

`env_key` names the variable Codex reads the key from, so export it in the shell rather than storing it here:

```sh
export CLIPROXY_API_KEY="$(yq -r '.api-keys[0]' /opt/homebrew/etc/cliproxyapi.conf)"
```

Check it resolves before relying on it:

```sh
codex doctor          # reports the active provider, its auth variable, and endpoint reachability
```

### opencode

The same shape the Proton Lumo provider already uses in `~/.config/opencode/opencode.json`:

```json
{
    "provider": {
        "cliproxy": {
            "npm": "@ai-sdk/openai-compatible",
            "name": "CLIProxyAPI",
            "options": {
                "baseURL": "http://127.0.0.1:8317/v1"
            }
        }
    }
}
```

`options.apiKey` takes the key. That file is app-written local state, not chezmoi source, so a key there is not committed, but it is plaintext on disk.

### Antigravity

Unverified. The Gemini-compatible endpoint exists, so the proxy can serve it, but no base-URL override for the Antigravity CLI has been confirmed. Do not assume an `OPENAI_BASE_URL` or `GEMINI_*` variable works here: the one in `manifests/gemini/mcp_config.json` configures an MCP server's environment, not the harness itself. Confirm against the CLI's own settings before wiring it.

## Verify

```sh
nc -z 127.0.0.1 8317 && echo listening
KEY="$(yq -r '.api-keys[0]' /opt/homebrew/etc/cliproxyapi.conf)"
curl -s -H "Authorization: Bearer ${KEY}" http://127.0.0.1:8317/v1/models
```

An empty `data` array means the server is healthy but no provider is logged in yet.

## Notes

The proxy holds provider credentials and answers to anything presenting the api key, which is why it binds loopback only and why the management API and its downloaded control panel stay disabled. Keep the api key out of both repos: the configure script writes it to the Homebrew config, Proton Pass holds the copy that survives a rebuild, and every harness above can read it at runtime rather than storing it.
