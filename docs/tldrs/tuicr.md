# tuicr

Rust Ratatui TUI for code review. Reviews local diffs AND GitHub PRs in the same binary. Vim keybindings, structured-markdown export for AI agents (Claude / Codex / Cursor), real PR-comment posting when run against a PR.

## Invocation

`tuicr()` in `~/.zshrc` defaults to `HEAD~1..HEAD` when called with no args. Explicit args bypass the default.

| Command | What it does |
|---|---|
| `tuicr` | Latest commit vs its parent (our wrapper; bare binary opens commit selector) |
| `tuicr all` | Entire repo as a diff against git's empty-tree SHA (every file = addition). Workaround for the missing all-files browse mode. |
| `tuicr -w` | Uncommitted working-tree changes |
| `tuicr -r main..HEAD` | Arbitrary revset / commit range |
| `tuicr -p path/to/file` | Filter diff to a single file or directory |
| `tuicr --file path` | Annotate a standalone file (no VCS required) |
| `tuicr pr 42` | Review GitHub PR #42 |
| `tuicr --stdout ...` | Export to stdout instead of clipboard |
| `command tuicr` | Bypass the wrapper (raw binary, commit selector) |

The `tuicr all` shortcut diffs HEAD against an ephemeral commit pointing to git's empty-tree SHA (`4b825dc6...`). libgit2 (tuicr's backend) rejects the bare tree SHA in a revset because revsets require commit-ish on both sides; wrapping it via `git commit-tree` produces a valid base. Every tracked file becomes a 100%-addition hunk against nothing. The wrapper commit is dangling — `git gc` cleans it up on its normal schedule (~30 days for unreachable objects). Useful when you want to scan the whole repo, leave notes anywhere, and pipe to an AI agent. Heavier than a normal diff: every line of every tracked file gets included.

## Colon-mode has no autocomplete

When you type `:`, tuicr's command-line accepts the full command verbatim. There is no tab-completion, fuzzy popup, or suggestion list (as of v0.14.1, no open issue requesting it). Either memorize the small set below, press `?` for the live help overlay, or refer to this TLDR.

## Save and quit — KEY GOTCHA

tuicr is vim-like: comments are "unsaved" until you take an explicit save/export action. **`q` alone warns about unsaved changes and refuses to quit cleanly.**

| Key / cmd | What it does |
|---|---|
| `:w` | Save the review session (annotations persist in tuicr's state) |
| `:clip` or `:export` | Copy structured review markdown to clipboard |
| `:x` or `:wq` | Save AND quit, prompts to copy to clipboard if comments exist |
| `ZZ` | Save and quit (vim shortcut for `:x`) |
| `:q` | Quit; warns if unsaved |
| `:q!` | Force quit, discards unsaved comments |
| `ZQ` | Quit without saving |
| `q` | "Quick quit" — warns if pending edits, does not auto-export |
| `:submit` | **PR-only**: posts comments back to GitHub as a real review. Errors on local diffs. |

**Local review workflow**: add comments → `:x` (saves + quits + prompts clipboard copy) → paste into Claude.

**PR review workflow**: `tuicr pr <num>` → add comments → `:submit` → pick Comment / Approve / Request changes / Draft.

## In-session keys

| Key | Action |
|---|---|
| `j` / `k` or `↓` / `↑` | Cursor down / up |
| `n` / `N` | Next / prev file |
| `[` / `]` | Prev / next hunk |
| `?` | Help overlay (live keymap) |
| `c` | Add comment on current line |
| `<leader>c` | Same — add comment (leader default `;`) |
| `<leader>h` / `<leader>l` | Focus file list / diff |
| `<leader>j` / `<leader>k` | Focus commit selector / diff |
| `<leader>e` | Toggle file list visibility — **keybinding-only**, no `:command` equivalent. If you forget, press `?` for the live keymap. |
| `:diff` | Toggle unified ⟷ side-by-side |

Below ~100 columns of terminal width, the file list auto-hides regardless of `<leader>e`.

## Comment classification

Structured-markdown export classifies each comment as one of:

- `ISSUE` — must fix
- `SUGGESTION` — proposal
- `NOTE` — informational
- `PRAISE` — positive feedback

This taxonomy is hardcoded as defaults. **Declaring any `[[comment_types]]` block in config replaces the entire taxonomy** (not additive); re-list defaults you want to keep alongside additions.

## Export format

Clipboard or stdout output looks like:

```markdown
## review of <ref or PR>

### path/to/file.rs:42 (ISSUE)
this is broken because X

### path/to/file.rs:88 (SUGGESTION)
consider Y instead
```

Pipe-to-agent pattern:

```bash
tuicr --stdout -w | claude --print "address these review comments"
tuicr --stdout -r main..HEAD > /tmp/review.md
tuicr --stdout pr 42 | pbcopy
```

## Config — what's set

Canonical source: `dotfiles/dot_config/tuicr/config.toml`, deploys to `~/.config/tuicr/config.toml`.

| Setting | Value | Why |
|---|---|---|
| `theme` | `"nord-dark"` | Match Ghostty / Starship Nord palette |
| `diff_view` | `"unified"` | Matches gitui convention; `:diff` toggles |
| `wrap` | `true` | Fold long lines instead of horizontal scroll |
| `scroll_offset` | `5` | Vim-style scrolloff |
| `mouse` | `true` | Click-to-position + wheel scroll |
| `leader` | `";"` | Default; rightmost-pinky reach |

`appearance` was removed — dead when `theme` is explicitly set; emitted a startup warning.

## Sources

- [docs/CONFIG.md](https://github.com/agavra/tuicr/blob/main/docs/CONFIG.md) — full config schema
- [docs/KEYBINDINGS.md](https://github.com/agavra/tuicr/blob/main/docs/KEYBINDINGS.md) — full keymap including all `:command` forms
- [tuicr GitHub repo](https://github.com/agavra/tuicr)
- [tuicr.dev](https://tuicr.dev/) — landing page with install methods
