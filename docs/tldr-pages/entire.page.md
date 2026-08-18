# entire

> Capture, inspect, and resume AI coding sessions through repository checkpoints.
> The local setup keeps session branches private by default.
> More information: <https://docs.entire.io/>.

- Show Entire state for the current repository:

`entire status`

- Enable local Claude Code checkpoints without uploading transcripts:

`entire enable --agent claude-code --skip-push-sessions --local --telemetry=false`

- List tracked sessions:

`entire session list`

- Resume the session attached to a branch:

`entire session resume {{branch}}`

- List checkpoints on the current branch:

`entire checkpoint list`

- Explain a checkpoint, commit, or session:

`entire checkpoint explain {{id_or_commit}}`

- Repair state after a history rewrite:

`entire doctor`

- Disable capture while keeping existing checkpoints:

`entire disable`
