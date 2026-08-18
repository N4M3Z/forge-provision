# revdiff

> Review local changes in a terminal interface and emit inline annotations.
> The local configuration includes untracked files and unified navigation.
> More information: <https://github.com/umputun/revdiff>.

- Review working-tree changes and untracked files:

`revdiff --untracked`

- Review staged changes:

`revdiff --staged`

- Review changes since a revision:

`revdiff {{revision}}`

- Compare two revisions:

`revdiff {{base_revision}} {{head_revision}}`

- Review one file:

`revdiff {{path/to/file}}`

- Browse every tracked file except a directory:

`revdiff --all-files -X {{directory}}`

- Print default key bindings:

`revdiff --dump-keys`
