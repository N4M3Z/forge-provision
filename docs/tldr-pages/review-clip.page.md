# review-clip

> Collect Zed review markers and format them as a tuicr Markdown review.
> Save editor buffers before use because the command reads files from disk.

- Copy all review comments to the macOS clipboard:

`review-clip`

- Print all review comments to standard output:

`review-clip --stdout`

- Send review comments to Claude Code:

`review-clip --stdout | claude --print "address these review comments"`
