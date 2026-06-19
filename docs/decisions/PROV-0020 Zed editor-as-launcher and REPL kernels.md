---
title: Zed editor-as-launcher and REPL kernels
description: Zed is configured as an agentic command surface, not just a text editor — a leader-keyed task suite launches terminal tools (git/jj TUIs, a Postgres browser, a review TUI, linters, markdown render, PDF export), markdown-oxide supplies PKM intelligence, editor-context commands run through an env-reading dispatcher to stay injection- and space-safe, and per-language Jupyter kernels back the REPL. Config splits public/private: a generic baseline in forge-provision, personal infra in the dotfiles lane.
type: adr
category: tooling
tags:
    - zed
    - tasks
    - repl
    - jupyter
    - pkm
    - editor
status: accepted
created: 2026-06-24
updated: 2026-06-24
author: "@N4M3Z"
project: forge-provision
related:
    - "PROV-0018 Zed markdown and PKM capability boundary.md"
    - "PROV-0016 Document rendering toolchain.md"
    - "PROV-0007 Brewfile manifest.md"
responsible: ["@N4M3Z"]
accountable: ["@N4M3Z"]
consulted: []
informed: []
upstream: []
---

# Zed editor-as-launcher and REPL kernels

## Context and Problem Statement

[PROV-0018](PROV-0018%20Zed%20markdown%20and%20PKM%20capability%20boundary.md) settled what Zed owns for markdown and where Obsidian stays the rendering surface. Past that boundary, Zed earns more by becoming a launching surface for the terminal tools already on the machine rather than acquiring features as extensions: its task runner can spawn a command in a pane, bound to a key, with editor context (`$ZED_FILE`, `$ZED_SELECTED_TEXT`, ...) supplied. The open questions were how to wire that cleanly, how to run code from inside notes, and how to keep a public provisioning repo free of personal infrastructure.

Two hazards shaped the design. First, Zed substitutes `$ZED_*` variables unquoted into the `zsh -i -c` string it runs, so interpolating a file path with spaces or an arbitrary selection into a task command is injection- and breakage-prone. Second, the working config mixes generic tooling with personal infrastructure (a knowledge-brain wrapper, vault-specific tasks, a brain database URL) that must not land in a public repo.

## Decision Drivers

- Launch the existing terminal toolchain from the editor without writing editor extensions (the extension API cannot host custom UIs anyway).
- Pass editor context to commands safely — no shell re-parsing of paths or selections.
- Run code blocks inside notes per language.
- Keep the public repo generic; personal infrastructure stays private.

## Decision Outcome

- **Editor-as-launcher via tasks + a leader keymap.** Terminal tools (gitui, jjui, a Postgres browser, the review TUI, shellcheck, gitleaks, a markdown pager, PDF export) are Zed tasks under a space-leader keymap, opened in a centered pane. Every task is also reachable from the task-spawn palette.
- **Env-reading dispatcher for editor-context commands.** Commands that need `$ZED_FILE` / `$ZED_SELECTED_TEXT` run through a small dispatcher invoked with only a literal action on its command line; it reads the editor variables from the environment (Zed exports them) rather than letting them be interpolated into a shell string. This is the injection- and space-safe pattern; plain no-argument tool launches use direct `command`/`args`.
- **REPL kernels for Python, TypeScript/JavaScript, Shell, and Ruby.** `repl::Run` runs a fenced block via a Jupyter kernel; Zed selects the kernel from the block's language. A single guarded, idempotent script registers them (ipykernel, Deno, bash_kernel, iruby). PHP and Rust are excluded: PHP's only kernel is unmaintained on a dead ZeroMQ extension, and Rust's evcxr recompiles on every evaluation.
- **Public/private config split.** forge-provision carries the generic baseline (`manifests/zed/`, the configure scripts, Brewfile deps, the moxide config, docs); the dotfiles lane carries the complete live config plus the personal wrapper commands, vault-specific tasks, and the brain context server. The baseline is a fresh-machine seed; the private lane is the daily driver.

### Consequences

- [+] One keypress launches any tool with editor context; the editor becomes the hub without extension development.
- [+] Editor variables never reach a shell parser, so paths with spaces and arbitrary selections are safe.
- [+] Runnable notes for four languages; the language set matches the toolchains actually installed.
- [+] The public repo stays generic and leak-free; personal infrastructure is isolated to the private lane.
- [-] The dispatcher and the personal tasks are duplicated knowledge across the two lanes (the generic baseline omits them).
- [-] REPL kernels are extra toolchain to install and maintain (a modern bash, Homebrew Ruby + libzmq); the kernels are dormant-but-working third-party software.
- [-] Two excluded languages (PHP, Rust) mean the REPL is not universal.

## Links

- [PROV-0018 Zed markdown and PKM capability boundary](PROV-0018%20Zed%20markdown%20and%20PKM%20capability%20boundary.md)
- [PROV-0016 Document rendering toolchain](PROV-0016%20Document%20rendering%20toolchain.md) — the pandoc/typst PDF-export task
- [Zed tasks](https://zed.dev/docs/tasks) · [Zed REPL](https://zed.dev/docs/repl)
