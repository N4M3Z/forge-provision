# tuicr

> Review local changes or GitHub pull requests in a terminal interface.
> The local shell wrapper reviews the latest commit when no arguments exist.
> More information: <https://tuicr.dev/>.

- Review the latest commit against its parent:

`tuicr`

- Review uncommitted working-tree changes:

`tuicr -w`

- Review a revision range:

`tuicr -r {{main..HEAD}}`

- Review one file:

`tuicr -p {{path/to/file}}`

- Review a GitHub pull request:

`tuicr pr {{pull_request_number}}`

- Export review comments to standard output:

`tuicr --stdout -w`

- Bypass the local shell wrapper and open the commit selector:

`command tuicr`
