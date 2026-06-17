# jj

> Jujutsu, a Git-compatible version control system, run colocated over an existing Git repo.
> More information: <https://docs.jj-vcs.dev/latest/>.

- Adopt jj in an existing Git repository, keeping `.git/` alongside `.jj/`:

`jj git init --colocate`

- Set the description of the current change:

`jj describe -m "{{message}}"`

- Squash the working-copy change into its parent change:

`jj squash`

- Point a bookmark at a revision (bookmarks do not auto-advance like Git branches):

`jj bookmark set {{bookmark}} -r {{revision}}`

- Push bookmarks to the Git remote, signing all pushed commits in one batch:

`jj git push`

- Reconcile after a squash-merged pull request, dropping the emptied change:

`jj rebase -d {{main}}@origin --skip-emptied`

- Add an isolated working copy sharing one repository, for a parallel agent:

`jj workspace add {{path/to/workspace}}`

- Add a named parallel-agent workspace under the owning repo's ignored `.worktrees/` dir:

`jj workspace add --name {{topic}} .worktrees/{{topic}}`

- List all known workspaces and their roots:

`jj workspace list`

- Forget a retired workspace; delete files separately:

`jj workspace forget {{workspace-name}}`

- Refresh a workspace that went stale after another workspace rewrote its `@`:

`jj workspace update-stale`

- Undo the last operation:

`jj undo`
