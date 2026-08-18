# review-strip

> Find or remove Zed review marker lines in Git-tracked files.
> Use check mode as a gate before a commit or push.

- List every review marker without changing files:

`review-strip`

- Fail when any review marker remains:

`review-strip --check`

- Remove every whole-line review marker:

`review-strip --apply`
