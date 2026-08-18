# pxpipe

> Run the local Claude request-compression proxy.
> The Claude shell wrapper starts it automatically and falls back when unavailable.
> More information: <https://github.com/teamchong/pxpipe>.

- Start the proxy manually:

`pxpipe`

- Route one Claude session through the local proxy:

`ANTHROPIC_BASE_URL=http://127.0.0.1:47821 claude`

- Disable proxy use for the current shell:

`export PXPIPE_DISABLE=1`

- Open the local usage dashboard:

`open http://127.0.0.1:47821/`

- Remove the pinned proxy package:

`bun remove --global pxpipe-proxy`
