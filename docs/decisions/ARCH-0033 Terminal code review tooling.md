---
title: Terminal code review tooling
description: tuicr and revdiff are both installed for terminal code review of AI-session diffs; both are good, with tuicr preferred as the default because it alone also posts real GitHub PR comments and exports classified markdown for agents. revdiff is the equal pick for local-only review.
type: adr
category: tooling
tags:
    - code-review
    - tuicr
    - revdiff
    - tui
    - ai-agents
    - workflow
status: accepted
created: 2026-06-13
updated: 2026-06-13
author: "@N4M3Z"
project: forge-provision
related:
    - "ARCH-0028 Session persistence Entire CLI.md"
    - "ARCH-0032 Multi-agent version control with Jujutsu.md"
    - "ARCH-0010 Primary terminal emulator Ghostty.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Terminal code review tooling

## Context and Problem Statement

An AI session produces a stream of diffs that the operator reviews before they land. Doing that review by bouncing between a GUI editor and the terminal breaks the loop: the review notes have to be retyped as the next prompt, and the context of "what the agent just did" is lost in the window switch. Two distinct review modes need covering. The first is local, pre-commit review of uncommitted or just-committed changes, where the operator reads hunks and drops inline notes the same way they would comment on a tool call, then feeds the notes back to the agent. The second is asynchronous GitHub PR review, where the work was committed and pushed and the operator wants a [gitui](<ARCH-0007 Shell environment.md>)-style interface to post real PR comments rather than the web UI.

A tool that covers both modes and emits agent-consumable structured output is preferable to stitching two tools together, because the review-then-reprompt loop is the same in both cases. The tool also needs to launch as a terminal overlay so it composes with the [Ghostty](<ARCH-0010 Primary terminal emulator Ghostty.md>) / multiplexer host rather than taking over the session.

## Decision Drivers

- One tool able to span local pre-commit review and asynchronous GitHub PR review
- Structured, classified export (must-fix vs suggestion vs note) for piping into an agent prompt
- Real PR-comment posting, not just a local scratchpad
- Vim-style keys to match the rest of the terminal stack
- Composes as a terminal overlay with the existing emulator and multiplexer

## Considered Options

1. **tuicr** — Rust Ratatui TUI. Reviews local diffs (`-w`, `-r`, `--file`, whole-repo) and GitHub PRs (`tuicr pr <n>` with `:submit` posting a real review) in one binary. Structured-markdown export classified as ISSUE / SUGGESTION / NOTE / PRAISE.
2. **revdiff** — Go Bubble Tea TUI purpose-built for reviewing AI-session diffs with inline annotations emitted to stdout. Local diffs only; does not post to GitHub PRs. Ships dedicated OpenCode and Claude Code plugins and a rich in-session display (collapsed, compact, word-diff, blame, gitui-style tree).
3. **octo.nvim** — Neovim-native PR review. Strong if the editor is already Neovim, but couples review to one editor and does no local pre-commit diff review.
4. **gh-dash + gh-review** — two `gh` extensions stitched together for PR triage and review. Narrower than a dedicated reviewer and split across two tools.
5. **prr** — file-edit-as-review metaphor (edit a generated review file). Superseded by the interactive TUIs.

## Decision Outcome

Chosen option: **install both tuicr and revdiff; tuicr is the preferred default.** Both are good, and they are kept side by side rather than one displacing the other. tuicr is the default because it is the only candidate that covers both review modes in one binary: the local need (read hunks, annotate, reprompt) and the PR need (post classified comments back to GitHub) are served by the same interface and the same structured export, with nothing to stitch. Its classified taxonomy maps directly onto how the agent should treat each note. The operator also contributes upstream, so a missing feature becomes an upstream change rather than a permanent workaround. tuicr is wired into the rest of the setup: its config is [chezmoi](<ARCH-0005 Dotfiles engine chezmoi.md>)-managed and a shell wrapper defaults a bare invocation to the last commit.

revdiff is the equally good pick for purely local review. Its richer in-session display (the collapse, compact, word-diff, and blame toggles, plus the gitui-style tree panel) and its first-class OpenCode and Claude Code plugins make it the lighter, more ergonomic choice when no PR is involved. It does not post to PRs, so the two are complementary: reach for revdiff for a local skim, reach for tuicr when the same review continues into a posted PR.

### Consequences

- [+] One tool (tuicr) spans pre-commit local review and asynchronous PR review; no two-tool stitching required
- [+] Classified structured export from either tool feeds straight into an agent reprompt
- [+] Upstream contribution to tuicr turns missing features into patches rather than permanent gaps
- [-] The daily tuicr binary is a locally built fork that shadows the Homebrew build via PATH order; the two report the same version, so a PATH regression is silent and must be checked with `which tuicr`
- [-] Two reviewers to keep in mind; the split (revdiff for a local skim, tuicr for the primary loop and PR posting) has to be remembered

## Links

- [tuicr](https://github.com/agavra/tuicr) — preferred default reviewer
- [revdiff](https://github.com/umputun/revdiff) — equally good for local-only review
