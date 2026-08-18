- Open the local Jujutsu terminal interface:

`jjui`

- Add a named workspace for an isolated agent change:

`jj workspace add --name {{topic}} .worktrees/{{topic}}`

- Refresh a workspace after another workspace rewrites its current change:

`jj workspace update-stale`

- Rebase after a squash merge and discard emptied changes:

`jj rebase -d main@origin --skip-emptied`

- Show the current linear change stack:

`jj log -r '::@'`
