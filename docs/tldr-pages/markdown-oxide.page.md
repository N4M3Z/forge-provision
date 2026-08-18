# markdown-oxide

> Start the Markdown language server that provides wikilinks, backlinks, and note diagnostics.
> Zed normally starts the server through its Markdown Oxide extension.
> More information: <https://oxide.md/>.

- Start the language server over standard input and output:

`markdown-oxide`

- Open the global configuration:

`${EDITOR:-zed} ~/.config/moxide/settings.toml`

- Open a vault-specific configuration:

`${EDITOR:-zed} {{path/to/vault}}/.moxide.toml`

- Seed the global configuration from forge-provision when absent:

`./scripts/configure/markdown-oxide.sh`
